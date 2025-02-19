--!strict

local bytecode = require("bytecode")
local compile = require("compiler")
local object = require("evaluator/object")

local opcodes = bytecode.opcodes

local STACK_SIZE = 2048
local sp = 0

local constants: {object.BaseObject<unknown>} = {}
local stack: {object.BaseObject<unknown>} = {}

-- Holds the last element on the stack before it is popped
local last_element: object.BaseObject<unknown>? = nil

local function swap_endianess(number: number): number
	local low = bit32.band(number, 0xFF)
	local high = bit32.band(bit32.rshift(number, 8), 0xFF)

	return bit32.bor(bit32.lshift(low, 8), high)
end

local function push(obj: object.BaseObject<unknown>): string?
	if sp >= STACK_SIZE then
		return "stack overflow"
	end

	stack[sp] = obj
	sp += 1

	return
end

local function pop(): object.BaseObject<unknown>
	local obj = stack[sp-1]
	stack[sp-1] = nil
	sp -= 1

	last_element = obj
	return obj
end

return function(consts: {object.BaseObject<unknown>}, instructions: bytecode.Instruction): (string?, typeof(last_element))
	sp = 0
	stack = table.create(STACK_SIZE)
	constants = consts
	last_element = nil 

	local len = buffer.len(instructions)

	local ip = 0
	local const_index = nil

	while ip < len do
		local op = buffer.readu8(instructions, ip)

		if op == opcodes.OP_CONSTANT then
			const_index = swap_endianess(buffer.readu16(instructions, ip + 1)) -- BE to LE
			ip += 2

			local err = push(constants[const_index + 1])
			if err then return err, last_element end
		elseif op == opcodes.OP_ADD then
			local right = pop()
			local left = pop()

			local result = (left :: object.BaseObject<number>).value + (right :: object.BaseObject<number>).value
			push({
				obj_type = object.kinds.NUMBER,
				value = result
			} :: object.BaseObject<number>)
		elseif op == opcodes.OP_POP then
			pop()
		end

		ip += 1
	end

	return nil, last_element
end
