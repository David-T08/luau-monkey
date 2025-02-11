local AST = require("../../../components/ast")
local lex = require("../../../components/lexer")
local parse = require("../../../components/parser")
local object = require("../../../components/evaluator/object")
local compile = require("../../../components/compiler")
local vm = require("../../../components/vm")

local assert, it = require("../globals")
local format = require("../../format")

type VMTestCase = {
	input: string,
	expected: any
}

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

local function test_integer_object(expected: number, got: object.BaseObject<number>)
	expect("NUMBER", got, 4)
	assert.are_equal(got.value, expected, `Expected value to be $2, got $1`, 4)
end

local function test_expected_object(expected: any, got: object.BaseObject<unknown>)
	local typ = typeof(expect)
	if typ == "number" then
		test_integer_object(expected, got :: any)
	end
end

local function run_vm_tests(tests: {VMTestCase})
	for _, test in ipairs(tests) do
		local program = parse(lex(test.input))

		local err, compiled = compile(program)
		assert.are_equal(err, nil, `Failed to compile: $1`)

		local vm_err, stack, sp = vm(compiled.constants, compiled.instructions)
		assert.are_equal(vm_err, nil, `VM failed to run: $1`)

		local stack_top = stack[sp - 1]
		test_expected_object(test.expected, stack_top)
	end
end

return {
	describe = "the vm",
	tests = {
		it("can do integer arithmetic", function()
			local tests: {VMTestCase} = {
				{input = "1", expected = 1},
				{input = "2", expected = 2},
				{input = "1 + 2", expected = 2}
			}

			run_vm_tests(tests)
		end)
	}
}