--!strict
local stdio = require("@lune/stdio")

type testRequest = {
	label: string,
	callback: (input: any) -> (),
}

type testResult = {
	success: boolean,
	error: {
		err: string,
		file: string,
		line: string,

		type: "Failure" | "Error",
	}?,

	label: string,
	describe: string,

	elapsed: number,
}

local function pluralize(str: string, count: number)
	if count == 1 then
		return str
	end
	if str == "success" then
		return str .. "es"
	end

	return str .. "s"
end

local function color(str: string | number, color: stdio.Color)
	return stdio.color(color) .. str .. stdio.color("reset")
end

local function style(str: string | number, style: stdio.Style)
	return stdio.style(style) .. str .. stdio.style("reset")
end

local err_pattern = '%[string "([%w%._/]+)"]:(%d+): (.+)'

local function runTests(...: { describe: string, tests: { testRequest } })
	local results: { testResult } = {}
	local visual_line = {}

	local total_elapsed = 0

	local successes = 0
	local failures = 0
	local errors = 0

	for _, test_spec in ipairs({ ... }) do
		for _, test in ipairs(test_spec.tests) do
			local start = os.clock()
			local success, err: string = pcall(test.callback :: any)
			local ended = os.clock()

			total_elapsed += ended - start

			local result: testResult = {
				elapsed = ended - start,
				success = success,

				describe = test_spec.describe,
				label = test.label
			}

			if not success then
				local didFail = 0
				local file, lineno, new_err = err:match(err_pattern)
				new_err, didFail = new_err:gsub("%[!!FAILURE!!%]", "")
				
				local new_file, new_lineno = new_err:match("%[!!([%w%._/]+)!!(%d+)!!%]")
				file = new_file or file
				lineno = new_lineno or lineno

				new_err = new_err:gsub("%[!!([%w%._/]+)!!(%d+)!!%]", "")

				result.error = {
					file = file,
					line = lineno,
					err = new_err,

					type = if didFail == 1 then "Failure" else "Error",
				}

				if didFail == 1 then
					table.insert(visual_line, color("▲", "red"))
					failures += 1
				else
					table.insert(visual_line, color("◆", "purple"))
					errors += 1
				end
			else
				table.insert(visual_line, color("●", "green"))
				successes += 1
			end

			table.insert(results, result)
		end
	end

	print(table.concat(visual_line))

	local result_line = `{color(successes, "green")} {pluralize("success", successes)} / `
		.. `{color(failures, "red")} {pluralize("failure", failures)} / `
		.. `{color(errors, "purple")} {pluralize("error", errors)} : `
		.. `{style(total_elapsed, "bold")} seconds`

	print(result_line)
	print(
		`{color(`{successes}/{successes + errors + failures}`, "yellow")} passed, {color(
			string.format("%.2f", (successes / (failures + errors + successes)) * 100) .. "%",
			"yellow"
		)} coverage`
	)

	for index, result in ipairs(results) do
		if result.success or not result.error then
			continue
		end
		print()

		local err_color = if result.error.type == "Failure" then "red" else "purple"

		print(
			`{color(result.error.type, err_color :: any)} → {color(result.error.file, "cyan")} @ {color("?", "cyan")}`
		)
		print(style(`{result.describe} {result.label}`, "bold"))
		print(`{result.error.file}:{result.error.line}: {result.error.err}`)
		print()
	end
end

runTests(
	require("specs/lexer_spec"), 
	require("specs/parser_spec"), 
	require("specs/evaluator_spec"),
	require("specs/bytecode_spec"),
	require("specs/compiler_spec"),
	require("specs/vm_spec"),
  require("specs/symbol_spec")
)
