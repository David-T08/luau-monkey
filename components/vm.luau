--!strict
local bytecode = require("bytecode")
local object = require("evaluator/object")
local format = require("../debug/format")

local opcodes = bytecode.opcodes

local STACK_SIZE = 2048
local sp = 0

local constants: { object.BaseObject<unknown> } = {}
local stack: { object.BaseObject<unknown> } = {}
local globals: { object.BaseObject<unknown> } = {}

-- Holds the last element on the stack before it is popped
local last_element: object.BaseObject<unknown>? = nil

local _debug = false
function log(...)
	if not _debug then
		return
	end
	print(...)
end

local function swap_endianess(number: number): number
	local low = bit32.band(number, 0xFF)
	local high = bit32.band(bit32.rshift(number, 8), 0xFF)

	return bit32.bor(bit32.lshift(low, 8), high)
end

local function push(obj: object.BaseObject<unknown>): string?
	if not obj then
		return `invalid object push`
	end

	log(`Pushed {format(obj)} at sp {sp}`)
	if sp >= STACK_SIZE then
		log(` Overflowed`)
		return "stack overflow"
	end

	stack[sp] = obj
	sp += 1

	return
end

local function pop(): (string?, object.BaseObject<unknown>)
	local obj = stack[sp - 1]
	if obj == nil then
		log(` Underflowed`)
		return `stack underflow`, {} :: any
	end
  log(`Popped {format(obj)} at sp {sp - 1}`)

	stack[sp - 1] = nil
	sp -= 1

	last_element = obj
	return nil, obj
end

local function execute_binary_operation(op: number): string?
	local r_err, right = pop()
	local l_err, left = pop()
	-- log(`Binary operation between {right}`)
	log(`Executing binary operation {bytecode.definitions[op].name} ({op})`)
	if l_err then
		log(` Failed to pop left: {l_err}`)
		return
	end
	if r_err then
		log(` Failed to pop right: {r_err}`)
		return
	end

	if left.obj_type == object.kinds.NUMBER and right.obj_type == object.kinds.NUMBER then
		log(` Integer operation between {left.value} and {right.value}`)
		local result = 0

		if op == opcodes.OP_ADD then
			result = (left :: object.Number).value + (right :: object.Number).value
		elseif op == opcodes.OP_SUB then
			result = (left :: object.Number).value - (right :: object.Number).value
		elseif op == opcodes.OP_DIV then
			result = (left :: object.Number).value / (right :: object.Number).value
		elseif op == opcodes.OP_MUL then
			result = (left :: object.Number).value * (right :: object.Number).value
		else
			return `unknown integer operator {op}`
		end

		return push({
			obj_type = object.kinds.NUMBER,
			value = result,
		} :: object.Number)
  elseif left.obj_type == object.kinds.STRING and right.obj_type == object.kinds.STRING then
    if op ~= opcodes.OP_ADD then 
      return `unknown string operator {op}`
    end

    return push({
      obj_type = object.kinds.STRING,
      value = (left :: object.String).value .. (right :: object.String).value 
    })
	else
		return `unsupported types for binary operation {left.obj_type} {right.obj_type}`
	end
end

function execute_comparison(op: number): string?
	log(`Executing comparison {bytecode.definitions[op].name} ({op})`)

	local r_err, right = pop()
	if r_err then
		log(` Failed to pop right: {r_err}`)
		return r_err
	end
	local l_err, left = pop()
	if l_err then
		log(` Failed to pop left: {l_err}`)
		return l_err
	end

	if left.obj_type == object.kinds.NUMBER and right.obj_type == object.kinds.NUMBER then
		log(` Integer comparison between {left.value} and {right.value}`)
		if op == opcodes.OP_EQUAL then
			return push(object.constants[left.value == right.value])
		elseif op == opcodes.OP_NOT_EQUAL then
			return push(object.constants[left.value ~= right.value])
		elseif op == opcodes.OP_GREATER_THAN then
			return push(object.constants[(left.value :: any) > (right.value :: any)])
		elseif op == opcodes.OP_GREATER_THAN_EQUAL then
			return push(object.constants[(left.value :: any) >= (right.value :: any)])
		end
	elseif left.obj_type == object.kinds.BOOLEAN and right.obj_type == object.kinds.BOOLEAN then
		log(` Boolean comparison between {left.value} and {right.value}`)
		if op == opcodes.OP_EQUAL then
			return push(object.constants[left.value == right.value])
		elseif op == opcodes.OP_NOT_EQUAL then
			return push(object.constants[left.value ~= right.value])
		end
	end

	return `unknown operator: {op} ({left.obj_type} {right.obj_type})`
end

return function(
	consts: { object.BaseObject<unknown> },
	instructions: bytecode.Instruction,
	debugging: boolean?,
  prev_globals: {object.BaseObject<unknown>}?
): (string?, typeof(last_element))
	stack = table.create(STACK_SIZE)
	globals = prev_globals or {}
	constants = consts

	sp = 0
	last_element = nil
	_debug = debugging or false

	local len = buffer.len(instructions)

	local ip = 0
	local const_index = nil

	if _debug then
		local c_out = {}
		for i, constant in ipairs(constants) do
			table.insert(c_out, ` [{i}]: {format(constant)}`)
		end

		c_out = table.concat(c_out, "\n ") :: any

		log(
			`Initialized new VM{if #c_out > 0 then `\nConstants:\n {c_out}` else ""}\nBytecode:\n{format(instructions)}`
		)
		log()
	end

	while ip < len do
		local op = buffer.readu8(instructions, ip)
		log(`Read {bytecode.definitions[op].name} ({op}) at ip {ip}`)

		if op == opcodes.OP_CONSTANT then
			const_index = swap_endianess(buffer.readu16(instructions, ip + 1)) -- BE to LE
			ip += 2

			local err = push(constants[const_index + 1])
			if err then
				return err
			end
		elseif op == opcodes.OP_ADD or op == opcodes.OP_SUB or op == opcodes.OP_DIV or op == opcodes.OP_MUL then
			local err = execute_binary_operation(op)
      if err then return err end
		elseif op == opcodes.OP_TRUE then
			local err = push(object.constants[true])
			if err then
				return err
			end
		elseif op == opcodes.OP_FALSE then
			local err = push(object.constants[false])
			if err then
				return err
			end
		elseif op == opcodes.OP_POP then
			local err = pop()
			if err then
				return err
			end
		elseif
			op == opcodes.OP_GREATER_THAN
			or op == opcodes.OP_GREATER_THAN_EQUAL
			or op == opcodes.OP_EQUAL
			or op == opcodes.OP_NOT_EQUAL
		then
			local err = execute_comparison(op)
			if err then
				return err
			end
		elseif op == opcodes.OP_BANG then
			log(`Evaluating bang operator`)
			local err, value = pop()
			if err then
				log(` Failed to pop: {err}`)
				return err
			end

			local chosen: object.BaseObject<boolean> = nil

			if value.value == true then
				chosen = object.constants[false]
			elseif value.value == false or value.obj_type == object.kinds.NULL then
				chosen = object.constants[true]
			else
				chosen = object.constants[false]
			end

			local err2 = push(chosen)
			if err2 then
				log(` Failed to push: {err2}`)
				return err2
			end
		elseif op == opcodes.OP_NEGATE then
			log(`Evaluating negate operator`)
			local err, value = pop()
			if err then
				log(` Failed to pop: {err}`)
				return err
			end

			if value.obj_type ~= object.kinds.NUMBER then
				return `unsupported type for negation: {value.obj_type}`
			end

			local err2 = push({
				obj_type = object.kinds.NUMBER,
				value = -value.value :: number,
			} :: object.Number)
			if err2 then
				log(` Failed to push: {err2}`)
				return err2
			end
		elseif op == opcodes.OP_JMP then
			local pos = swap_endianess(buffer.readu16(instructions, ip + 1))
			ip = pos - 1
		elseif op == opcodes.OP_JMP_COND then
			local pos = swap_endianess(buffer.readu16(instructions, ip + 1))
			ip += 2

			local c_err, condition = pop()
			if c_err then
				return c_err
			end

			local truthy = true
			if condition.obj_type == object.kinds.BOOLEAN then
				truthy = condition.value :: any
			elseif condition.obj_type == object.kinds.NULL then
				truthy = false
			end

			-- Check if it is not truthy
			if not truthy then
				ip = pos - 1
			end
		elseif op == opcodes.OP_NULL then
			local err = push(object.constants.null)
			if err then
				return err
			end
    elseif op == opcodes.OP_SET_GLOBAL then
			local index = swap_endianess(buffer.readu16(instructions, ip + 1))
			ip += 2

      local err, value = pop()
      if err then
        return err
      end

      globals[index] = value
    elseif op == opcodes.OP_GET_GLOBAL then
			local index = swap_endianess(buffer.readu16(instructions, ip + 1))
			ip += 2

      local err = push(globals[index])
      if err then
        return err
      end
		end

		ip += 1
	end

	log()
	return nil, last_element
end
