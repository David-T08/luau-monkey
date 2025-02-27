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

local last_instr_pos: number = 0
local last_instr_op: number = 0

local prev_instr_pos: number = 0
local prev_instr_op: number = 0

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

local function dealloc(bytes: number)
	if offset - bytes < 0 then
		return
	end

	log(`De-allocating {bytes} bytes`)

	size -= bytes
  offset -= bytes

	local new = _buffer_new(size)
	_buffer_copy(new, 0, instructions, 0, size)
  
	instructions = new
end

local function replace_instruction(pos: number, instruction: buffer)
  _buffer_copy(instructions, pos, instruction)
end

local function change_operand(op_pos: number, operand: number)
  replace_instruction(op_pos, make(
    buffer.readu8(instructions, op_pos), 
    operand)
  )
end

local function emit(op: number, ...: number): number
  local ops = table.concat({...}, ", ")

	log(`Emitting {op} ({definitons[op].name}){if #ops > 0 then `; operands: \{{ops}}` else ""}`)
	local instruction = make(op, ...)
	local len = buffer.len(instruction)
	log(`  Generated instruction of length {len}`)

	alloc(len)
	_buffer_copy(instructions, offset, instruction)
	log(`  Copied to program at offset: {string.format("%08X", offset)}`)

	offset += len

  prev_instr_pos = last_instr_pos
  prev_instr_op = last_instr_op

  last_instr_op = op
  last_instr_pos = offset

  return offset - len
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

    last_instr_op = 0
    last_instr_pos = 0

    prev_instr_op = 0
    prev_instr_pos = 0
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
    local err = compile((node :: AST.PrefixExpression).right, debugging)
    if err then return err end

    local operator = (node :: AST.PrefixExpression).operator
    if operator == "!" then
      emit(opcodes.OP_BANG)
    elseif operator == "-" then
      emit(opcodes.OP_NEGATE)
    end
  elseif node.node_type == AST.IF_EXPRESSION then
    reset = false
    local cond_err = compile((node :: AST.IfExpression).condition, debugging)
    if cond_err then
      return cond_err
    end

    -- Emit a jmp to a fake offset, we'll update it later after compiliation
    local jmp_cond_pos = emit(opcodes.OP_JMP_COND, 9999)

    reset = false
    local consequence_err = compile((node :: AST.IfExpression).consequence, debugging)
    if consequence_err then
      return consequence_err
    end

    -- Remove the last pop
    if last_instr_op == opcodes.OP_POP then
      last_instr_op = prev_instr_op
      last_instr_pos = prev_instr_pos
    
      dealloc(1)
    end

    -- Generate fake offset to change later
    -- Jump past the above jump so we dont skip the alternative
    local jmp_pos = emit(opcodes.OP_JMP, 9999)
    -- Update the conditional jump to point to the alternative
    change_operand(jmp_cond_pos, offset)
    
    if (node :: AST.IfExpression).alternative == nil then
      -- Emit null for the alternative
      emit(opcodes.OP_NULL)
    else
			reset = false
			local alternate_err = compile((node :: AST.IfExpression).alternative :: any, debugging)
			if alternate_err then
				return alternate_err
			end

			-- Remove the last pop
			if last_instr_op == opcodes.OP_POP then
				last_instr_op = prev_instr_op
				last_instr_pos = prev_instr_pos

				dealloc(1)
      end
    end
    
    -- Jump to the end of the block
    change_operand(jmp_pos, offset)
  elseif node.node_type == AST.BLOCK_STATEMENT then
    for _, stmt in ipairs((node :: AST.BlockStatement).statements) do
      local err = compile(stmt, debugging)
      if err then 
        return err
      end
    end
	end

	reset = true
	return nil, {
		instructions = instructions,
		constants = constants,
	}
end

return compile
