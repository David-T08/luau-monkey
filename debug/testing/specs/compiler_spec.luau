local bytecode = require("../../../components/bytecode")
local compile = require("../../../components/compiler")
local object = require("../../../components/evaluator/object")
local parse = require("../../../components/parser")
local lex = require("../../../components/lexer")
local ast = require("../../../components/ast")

local opcodes = bytecode.opcodes
local make = bytecode.make

local assert, it = require("../globals")
local format = require("../../format")

type CompilerTest = {
	input: string,
	expected_constants: {any},
	expected_instructions: {bytecode.Instruction}
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
	assert.are_equal(
		expr_typeof(expr),
		what,
		`Expected object to be an $2, got $1`,
		err_lvl
	)
end

local function test_integer_object(expected: number, got: object.BaseObject<number>)
	expect("NUMBER", got, 4)
	assert.are_equal(got.value, expected, `Expected value to be $2, got $1`, 4)
end

local function concat_instructions(instructions: {bytecode.Instruction}): bytecode.Instruction
	local size = 0
	for _, instr in ipairs(instructions) do
		size += buffer.len(instr)
	end

	local out = buffer.create(size)
	local offset = 0
	for _, instr in ipairs(instructions) do
		buffer.copy(out, offset, instr)
		offset += buffer.len(instr)
	end

	return out
end

local function test_instructions(expected: {bytecode.Instruction}, got: bytecode.Instruction)	
	local concatted = concat_instructions(expected)
	assert.are_equal(buffer.len(got), buffer.len(concatted), `Instruction has wrong length, got: $1, expected: $2`, 4)

	for byte = 1, buffer.len(concatted) do
		assert.are_equal(
			buffer.readu8(got, byte - 1),
			buffer.readu8(concatted, byte - 1),
			`\nWrong byte at 0x{string.format("%08X", byte - 1)}, got: $1, expected: $2\n\nGot:\n{format(got)}\nExpected:\n{format(expected)}`,
			4
		)
	end
end

local function test_constants(expected: { any }, got: {object.BaseObject<unknown>})
	assert.are_equal(#got, #expected, `Wrong number of constants, got: $1, expected: $2`)

	for index, constant in ipairs(expected) do
		local typ = typeof(constant)
		if typ == "number" then
			test_integer_object(constant, got[index] :: any)
		end
	end
end

local function run_compiler_tests(tests: {CompilerTest})
	for _, test in ipairs(tests) do
		local program = parse(lex(test.input))
		local err, output = compile(program)
		if err then
			error(`Failed to compile: {err}`)
		end

		test_instructions(test.expected_instructions, output.instructions)
		test_constants(test.expected_constants, output.constants)
	end
end

return {
	describe = "the compiler",
	tests = {
		it("can do integer arithmetic", function()
			local tests: {CompilerTest} = {
				{
					input = "1 + 2",
					expected_constants = {1,2},
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_ADD)
					}
				}
			}

			run_compiler_tests(tests)
		end),
	},
}
