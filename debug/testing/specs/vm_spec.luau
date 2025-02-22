local AST = require("../../../components/ast")
local lex = require("../../../components/lexer")
local parse = require("../../../components/parser")
local object = require("../../../components/evaluator/object")
local compile = require("../../../components/compiler")
local vm = require("../../../components/vm")

local assert, it = require("../globals")
local format = require("../../format")

local OBJ_TYPES_STRINGS = table.freeze({
	[object.kinds.STRING] = "STRING",
	[object.kinds.NUMBER] = "NUMBER",
	[object.kinds.BOOLEAN] = "BOOLEAN",
	[object.kinds.ERROR] = "ERROR",
	[object.kinds.FUNCTION] = "FUNCTION",
	[object.kinds.ARRAY] = "ARRAY",
	[object.kinds.RETURN] = "RETURN",
	[object.kinds.NULL] = "NULL",
	[object.kinds.BUILTIN_FUNCTION] = "BUILTIN_FUNCTION",
})

local function expr_typeof(expr: object.BaseObject<unknown> | any): string
	local typ = type(expr)

	if typ == "table" then
		if type(expr.obj_type) == "number" then
			return OBJ_TYPES_STRINGS[expr.obj_type]
		end

		return expr.obj_type
	end

	if typ == "number" then
		return OBJ_TYPES_STRINGS[expr] or typ
	end

	return typ
end

local function expect(what, expr, err_lvl)
	assert.are_equal(expr_typeof(expr), what, `Expected object to be an $2, got $1`, err_lvl)
end

local function test_expected_object(expected: any, got: object.BaseObject<unknown>)
	local typ = typeof(expected)
	if typ == "number" then
		expect("NUMBER", got, 5)
		assert.are_equal(got.value, expected, `Expected value to be $2, got $1`, 5)
	elseif typ == "boolean" then
		expect("BOOLEAN", got, 5)
		assert.are_equal(got.value, expected, `Expected value to be $2, got $1`, 5)
	end
end

local function run_vm_tests(tests)
	for _, test in ipairs(tests) do
		local program = parse(lex(test[1]))

		local err, compiled = compile(program)
		assert.are_equal(err, nil, `Failed to compile: $1`)

		local vm_err, stack_top = vm(compiled.constants, compiled.instructions)
		assert.are_equal(vm_err, nil, `VM failed to run: $1`)

		test_expected_object(test[2], stack_top)
	end
end

return {
	describe = "the vm",
	tests = {
		it("can do integer arithmetic", function()
			local tests = {
				{ "1", 1 },
				{ "2", 2 },
				{ "1 + 2", 3 },
				{ "1 - 2", -1 },
				{ "1 * 2", 2 },
				{ "4 / 2", 2 },
				{ "50 / 2 * 2 + 10 - 5", 55 },
				{ "5 + 5 + 5 + 5 - 10", 10 },
				{ "2 * 2 * 2 * 2 * 2", 32 },
				{ "5 * 2 + 10", 20 },
				{ "5 + 2 * 10", 25 },
				{ "5 * (2 + 10)", 60 },
			}

			run_vm_tests(tests)
		end),

		it("can do boolean expressions", function()
			local tests = {
				{ "true", true },
				{ "false", false },
				{ "1 < 2", true },
				{ "1 > 2", false },
				{ "1 < 1", false },
				{ "1 > 1", false },
				{ "1 == 1", true },
				{ "1 != 1", false },
				{ "1 == 2", false },
				{ "1 != 2", true },
				{ "true == true", true },
				{ "false == false", true },
				{ "true == false", false },
				{ "true != false", true },
				{ "false != true", true },
				{ "(1 < 2) == true", true },
				{ "(1 < 2) == false", false },
				{ "(1 > 2) == true", false },
				{ "(1 > 2) == false", true },
			}

			run_vm_tests(tests)
		end),
	},
}
