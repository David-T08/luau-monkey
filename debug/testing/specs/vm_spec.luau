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
  [object.kinds.HASH] = "HASH"
})

function dictionary_len(dict): number
	local len = 0

	for _ in pairs(dict) do
		len += 1
	end

	return len
end

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

local function test_expected_object(expected: any, got: object.Unknown, is_hash: boolean?)
	local typ = typeof(expected)
	if typ == "number" then
		expect("NUMBER", got, 4)
		assert.are_equal(got.value, expected, `Expected value to be $2, got $1`, 4)
	elseif typ == "boolean" then
		expect("BOOLEAN", got, 4)
		assert.are_equal(got.value, expected, `Expected value to be $2, got $1`, 4)
	elseif typ == "table" then
    if is_hash then
      expect("HASH", got, 4)
			assert.are_equal(dictionary_len((got :: object.Hash).value), dictionary_len(expected), `Expected length to be $2, got $1`, 4)

      for expected_key, expected_value in pairs(expected) do
        test_expected_object(expected_value, (got :: object.Hash).value[expected_key])
      end
    else
      expect("ARRAY", got, 4)
      assert.are_equal(#(got :: object.Array).value, #expected, `Expected length to be $2, got $1`, 4)
  
      for i, expected_element in ipairs(expected) do
        local got_element = (got :: object.Array).value[i]
        expect("NUMBER", got_element, 4)
        assert.are_equal(got_element.value, expected_element, `Expected value to be $2, got $1`, 4)
      end
    end
	elseif typ == "nil" then
		expect("NULL", got, 4)
	end
end

local function run_vm_tests(tests, _debug: boolean?, is_hash: boolean?)
	for _, test in ipairs(tests) do
		local program = parse(lex(test[1]))

    if _debug then
      print(test[1])
    end

		local err, compiled = compile(program)
		assert.are_equal(err, nil, `Failed to compile: $1`)

		local vm_err, stack_top = vm(compiled.constants, compiled.instructions, _debug)
		assert.are_equal(vm_err, nil, `VM failed to run: $1`)

    assert.is.truthy(stack_top, `VM failed to pop`)

		-- print(stack_top, typeof(stack_top))

		test_expected_object(test[2], stack_top, is_hash)
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
				{ "-5", -5 },
				{ "-10", -10 },
				{ "-50 + 100 + -50", 0 },
				{ "(5 + 10 * 2 + 15 / 3) * 2 + -10", 50 },
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
				{ "!true", false },
				{ "!false", true },
				{ "!5", false },
				{ "!!true", true },
				{ "!!false", false },
				{ "!!5", true },
				{ "!(if (false) { 5; })", true },
			}

			run_vm_tests(tests)
		end),

		it("can do conditionals", function()
			local tests = {
				{ "if (true) { 10 }", 10 },
				{ "if (true) { 10 } else { 20 }", 10 },
				{ "if (false) { 10 } else { 20 } ", 20 },
				{ "if (1) { 10 }", 10 },
				{ "if (1 < 2) { 10 }", 10 },
				{ "if (1 < 2) { 10 } else { 20 }", 10 },
				{ "if (1 > 2) { 10 } else { 20 }", 20 },
				{ "if (1 > 2) { 10 }", nil },
				{ "if (false) { 10 }", nil },
				{ "!(if (false) { 5; })", true },
			}

			run_vm_tests(tests)
		end),

		it("can do global let statements", function()
			local tests = {
				{ "let one = 1; one", 1 },
				{ "let one = 1; let two = 2; one + two", 3 },
				{ "let one = 1; let two = one + one; one + two", 3 },
			}

			run_vm_tests(tests)
		end),

		it("can do string expressions", function()
			local tests = {
				{ `"monkey"`, "monkey" },
				{ `"mon" + "key"`, "monkey" },
				{ `"mon" + "key" + "banana"`, "monkeybanana" },
			}

			run_vm_tests(tests)
		end),

		it("can do arrays", function()
			local tests = {
				{ "[]", {} },
				{ "[1, 2, 3]", { 1, 2, 3 } },
				{ "[1 + 2, 3 * 4, 5 + 6]", { 3, 12, 11 } },
			}

			run_vm_tests(tests)
		end),

		it("can do hashes", function()
			local tests = {
				{
					"{}",
					{},
				},
				{
					"{1: 2, 2: 3}",
					{
						[1] = 2,
						[2] = 3,
					},
				},
				{
					"{1 + 1: 2 * 2, 3 + 3: 4 * 4}",
					{
						[2] = 4,
						[6] = 16,
					},
				},
			}

      run_vm_tests(tests, false, true)
		end),
	},
}
