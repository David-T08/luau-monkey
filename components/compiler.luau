--!strict

local AST, AST_STR = require("ast")
local bytecode = require("bytecode")
local object = require("evaluator/object")
local format = require("../debug/format")

local make = bytecode.make
local opcodes = bytecode.opcodes

local constants = {}
local instructions = buffer.create(0)
local size = 0
local offset = 0

local _buffer_copy = buffer.copy
local _buffer_new = buffer.create

local debugging = false

local function log(...: any)
	if not debugging then return end
	print(...)
end

local function alloc(bytes)
	if offset + bytes < size then
		return
	end

	log(`Allocating {bytes} bytes`)

	size += bytes
	local new = _buffer_new(size)
	_buffer_copy(new, 0, instructions)

	instructions = new
end

local function emit(op: number, ...: number)
	log(`Emitting {op}, operands: {table.concat({...}, ", ")}`)
	local instruction = make(op, ...)
	local len = buffer.len(instruction)
	log(`  Generated instruction of length {len}`)

	alloc(len)
	_buffer_copy(instructions, offset, instruction)
	log(`  Copied to program at offset: {string.format("%08X", offset)}`)

	offset += len
end

local reset = true
local function compile(node: AST.Node): (string?, {
	instructions: bytecode.Instruction,
	constants: { object.BaseObject<unknown> },
}?)
	log(`Compiling {AST_STR[node.node_type]}`)
	if reset then
		constants = {}
		instructions = _buffer_new(0)
		size, offset = 0, 0
	end

	if node.node_type == AST.PROGRAM then
		for _, stmt in ipairs((node :: AST.Program).statements) do
			reset = false
			local err = compile(stmt)
			if err then
				return err
			end
		end
	elseif node.node_type == AST.EXPRESSION_STATEMENT then
		reset = false
		local err = compile((node :: AST.ExpressionStatement).expression)
		if err then
			return err
		end
	elseif node.node_type == AST.INFIX_EXPRESSION then
		reset = false
		local err = compile((node :: AST.InfixExpression).left)
		if err then
			return err
		end

		reset = false
		err = compile((node :: AST.InfixExpression).right)
		if err then
			return err
		end
	elseif node.node_type == AST.INTEGER_LITERAL then
		local obj: object.BaseObject<number> = {
			obj_type = object.kinds.NUMBER,
			value = (node :: AST.IntegerLiteral).value,
		}

		table.insert(constants, obj)
		emit(opcodes.OP_CONSTANT, #constants - 1)
	end

	reset = true
	return nil, {
		instructions = instructions,
		constants = constants,
	}
end

return compile
