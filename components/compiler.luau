--!strict

local AST, AST_STR = require("ast")
local bytecode = require("bytecode")
local object = require("evaluator/object")
local format = require("../debug/format")

local make = bytecode.make
local opcodes = bytecode.opcodes
local definitons = bytecode.definitions

local constants = {}
local instructions = buffer.create(0)
local size = 0
local offset = 0

local _buffer_copy = buffer.copy
local _buffer_new = buffer.create

local _debug = false

local function log(...: any)
	if not _debug then
		return
	end
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
  local ops = table.concat({...}, ", ")

	log(`Emitting {op} ({definitons[op].name}){if #ops > 0 then `; operands: \{{ops}}` else ""}`)
	local instruction = make(op, ...)
	local len = buffer.len(instruction)
	log(`  Generated instruction of length {len}`)

	alloc(len)
	_buffer_copy(instructions, offset, instruction)
	log(`  Copied to program at offset: {string.format("%08X", offset)}`)

	offset += len
end

local reset = true
local function compile(node: AST.Node, debugging: boolean?): (string?, {
	instructions: bytecode.Instruction,
	constants: { object.BaseObject<unknown> },
}?)
  _debug = debugging or false
  if reset then
		log(`\nNEW COMPILATION`)
		constants = {}
		instructions = _buffer_new(0)
		size, offset = 0, 0
	end
	log(`Compiling {AST_STR[node.node_type]}`)

	if node.node_type == AST.PROGRAM then
		for _, stmt in ipairs((node :: AST.Program).statements) do
			reset = false
			local err = compile(stmt, debugging)
			if err then
				return err
			end
		end
	elseif node.node_type == AST.EXPRESSION_STATEMENT then
		reset = false
		local err = compile((node :: AST.ExpressionStatement).expression, debugging)
		if err then
			return err
		end
		emit(opcodes.OP_POP) -- Clean up old value from stack
	elseif node.node_type == AST.INFIX_EXPRESSION then
		local operator = (node :: AST.InfixExpression).operator
		local swap = operator == "<" or operator == "<="

		log(` Operator: {operator}, swap: {swap}`)
		log(` Node.left: {format((node :: AST.InfixExpression).left)}`)
		log(` Node.right: {format((node :: AST.InfixExpression).right)}`)

		reset = false
		local err = compile((node :: AST.InfixExpression)[if swap then "right" else "left"], debugging)
		if err then
			return err
		end

		reset = false
		err = compile((node :: AST.InfixExpression)[if swap then "left" else "right"], debugging)
		if err then
			return err
		end

		if operator == "+" then
			emit(opcodes.OP_ADD)
		elseif operator == "-" then
			emit(opcodes.OP_SUB)
		elseif operator == "/" then
			emit(opcodes.OP_DIV)
		elseif operator == "*" then
			emit(opcodes.OP_MUL)
		elseif operator == ">" or operator == "<" then
			emit(opcodes.OP_GREATER_THAN)
		elseif operator == ">=" or operator == "<=" then
			emit(opcodes.OP_GREATER_THAN_EQUAL)
		elseif operator == "==" then
			emit(opcodes.OP_EQUAL)
		elseif operator == "!=" then
			emit(opcodes.OP_NOT_EQUAL)
		else
			return `unknown operator {operator}`
		end
	elseif node.node_type == AST.INTEGER_LITERAL then
		local obj: object.BaseObject<number> = {
			obj_type = object.kinds.NUMBER,
			value = (node :: AST.IntegerLiteral).value,
		}

    log(` Inserted {obj.value}`)
		table.insert(constants, obj)
		emit(opcodes.OP_CONSTANT, #constants - 1)
	elseif node.node_type == AST.BOOLEAN_LITERAL then
		if (node :: AST.BooleanLiteral).value == true then
			emit(opcodes.OP_TRUE)
		else
			emit(opcodes.OP_FALSE)
		end
  elseif node.node_type == AST.PREFIX_EXPRESSION then
    local err = compile((node :: AST.PrefixExpression).right)
    if err then return err end

    local operator = (node :: AST.PrefixExpression).operator
    if operator == "!" then
      emit(opcodes.OP_BANG)
    elseif operator == "-" then
      emit(opcodes.OP_NEGATE)
    end
	end

	reset = true
	return nil, {
		instructions = instructions,
		constants = constants,
	}
end

return compile
