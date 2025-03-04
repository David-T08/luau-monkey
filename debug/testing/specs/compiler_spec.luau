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
	expected_constants: { any },
	expected_instructions: { bytecode.Instruction },
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

local function concat_instructions(instructions: { bytecode.Instruction }): bytecode.Instruction
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

local function test_instructions(expected: { bytecode.Instruction }, got: bytecode.Instruction)
	local concatted = concat_instructions(expected)
	assert.are_equal(
		buffer.len(got),
		buffer.len(concatted),
		`Instruction has wrong length, got: $1, expected: $2\n\nGot:\n{format(got)}\nExpected:\n{format(concatted)}`,
		4
	)

	for byte = 1, buffer.len(concatted) do
		assert.are_equal(
			buffer.readu8(got, byte - 1),
			buffer.readu8(concatted, byte - 1),
			`\nWrong byte at 0x{string.format("%08X", byte - 1)}, got: $1, expected: $2\n\nGot:\n{format(got)}\nExpected:\n{format(
				expected
			)}`,
			4
		)
	end
end

local function test_integer_object(expected: number, got: object.Number)
	expect("NUMBER", got, 5)
	assert.are_equal(got.value, expected, `Expected value to be $2, got $1`, 5)
end

local function test_string_object(expected: string, got: object.String)
  expect("STRING", got, 5)
	assert.are_equal(got.value, expected, `Expected value to be $2, got $1`, 5)
end

local function test_constants(expected: { any }, got: { object.BaseObject<unknown> })
	assert.are_equal(#got, #expected, `Wrong number of constants, got: $1, expected: $2`)

	for index, constant in ipairs(expected) do
		local typ = typeof(constant)
		if typ == "number" then
			test_integer_object(constant, got[index] :: any)
    elseif typ == "string" then
      test_string_object(constant, got[index] :: any)
		end
	end
end

local function run_compiler_tests(tests: { CompilerTest })
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
			local tests: { CompilerTest } = {
				{
					input = "1 + 2",
					expected_constants = { 1, 2 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_ADD),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "1; 2",
					expected_constants = { 1, 2 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_POP),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "1 - 2",
					expected_constants = { 1, 2 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_SUB),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "1 / 2",
					expected_constants = { 1, 2 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_DIV),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "1 * 2",
					expected_constants = { 1, 2 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_MUL),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "-1",
					expected_constants = { 1 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_NEGATE),
						make(opcodes.OP_POP),
					},
				},
			}

			run_compiler_tests(tests)
		end),

		it("can do boolean expressions", function()
			local tests: { CompilerTest } = {
				{
					input = "true",
					expected_constants = {},
					expected_instructions = {
						make(opcodes.OP_TRUE),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "false",
					expected_constants = {},
					expected_instructions = {
						make(opcodes.OP_FALSE),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "1 > 2",
					expected_constants = { 1, 2 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_GREATER_THAN),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "1 < 2",
					expected_constants = { 2, 1 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_GREATER_THAN),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "1 == 2",
					expected_constants = { 1, 2 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_EQUAL),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "1 != 2",
					expected_constants = { 1, 2 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_NOT_EQUAL),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "true == false",
					expected_constants = {},
					expected_instructions = {
						make(opcodes.OP_TRUE),
						make(opcodes.OP_FALSE),
						make(opcodes.OP_EQUAL),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "true != false",
					expected_constants = {},
					expected_instructions = {
						make(opcodes.OP_TRUE),
						make(opcodes.OP_FALSE),
						make(opcodes.OP_NOT_EQUAL),
						make(opcodes.OP_POP),
					},
				},
				{
					input = "!true",
					expected_constants = {},
					expected_instructions = {
						make(opcodes.OP_TRUE),
						make(opcodes.OP_BANG),
						make(opcodes.OP_POP),
					},
				},
			}

			run_compiler_tests(tests)
		end),

		it("can do conditionals", function()
			local tests: { CompilerTest } = {
				{
					input = "if (true) { 10; } 3333;",
					expected_constants = { 10, 3333 },
					expected_instructions = {
						make(opcodes.OP_TRUE), -- 0x0
						make(opcodes.OP_JMP_COND, 0xA), -- 0x1
						make(opcodes.OP_CONSTANT, 0), -- 0x4
						make(opcodes.OP_JMP, 0xB), -- 0x7
						make(opcodes.OP_NULL), -- 0xA
						make(opcodes.OP_POP), -- 0xB
						make(opcodes.OP_CONSTANT, 1), -- 0xC
						make(opcodes.OP_POP), -- 0xF
					},
				},
				{
					input = "if (true) { 10 } else { 20 } 3333;",
					expected_constants = { 10, 20, 3333 },
					expected_instructions = {
						make(opcodes.OP_TRUE), -- 0x0
						make(opcodes.OP_JMP_COND, 10), -- 0x1
						make(opcodes.OP_CONSTANT, 0), -- 0x4
						make(opcodes.OP_JMP, 13), -- 0x7,
						make(opcodes.OP_CONSTANT, 1), -- 0xA
						make(opcodes.OP_POP), -- 0xC
						make(opcodes.OP_CONSTANT, 2), -- 0xE
						make(opcodes.OP_POP), -- 0x1F
					},
				},
			}

			run_compiler_tests(tests)
		end),

		it("can do global let statements", function()
			local tests: {CompilerTest} = {
				{
					input = "let one = 1; let two = 2; ",
					expected_constants = { 1, 2 },
					expected_instructions = {
						make(opcodes.OP_CONSTANT, 0),
						make(opcodes.OP_SET_GLOBAL, 0),
						make(opcodes.OP_CONSTANT, 1),
						make(opcodes.OP_SET_GLOBAL, 1),
					},
				},
        {
          input = "let one = 1; one;",
          expected_constants = {1},
          expected_instructions = {
            make(opcodes.OP_CONSTANT, 0),
            make(opcodes.OP_SET_GLOBAL, 0),
            make(opcodes.OP_GET_GLOBAL, 0),
            make(opcodes.OP_POP)
          }
        },
        {
          input = "let one = 1;let two = one; two;",
          expected_constants = {1}, 
          expected_instructions = {
            make(opcodes.OP_CONSTANT, 0),
            make(opcodes.OP_SET_GLOBAL, 0),
            make(opcodes.OP_GET_GLOBAL, 0),
            make(opcodes.OP_SET_GLOBAL, 1),
            make(opcodes.OP_GET_GLOBAL, 1),
            make(opcodes.OP_POP)
          }
        }
			}

      run_compiler_tests(tests)
		end),

    it("can do string expressions", function()
      local tests: {CompilerTest} = {
        {
          input = '"monkey"',
          expected_constants = {"monkey"},
          expected_instructions = {
            make(opcodes.OP_CONSTANT, 0),
            make(opcodes.OP_POP)
          }
        },
        {
          input = '"mon" + "key"',
          expected_constants = {"mon", "key"},
          expected_instructions = {
            make(opcodes.OP_CONSTANT, 0),
            make(opcodes.OP_CONSTANT, 1),
            make(opcodes.OP_ADD),
            make(opcodes.OP_POP)
          }
        }
      }

      run_compiler_tests(tests)
    end)
	},
}
