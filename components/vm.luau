--!strict

local bytecode = require("bytecode")
local compile = require("compiler")
local object = require("evaluator/object")

local opcodes = bytecode.opcodes

local STACK_SIZE = 2048
local sp = 0

local constants: {object.BaseObject<unknown>} = {}
local stack: {object.BaseObject<unknown>} = {}

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

return function(consts: {object.BaseObject<unknown>}, instructions: bytecode.Instruction): (string?, typeof(stack), number)
	sp = 0
	stack = table.create(STACK_SIZE)
	constants = consts

	local len = buffer.len(instructions)

	local ip = 0
	local const_index = nil

	while ip < len do
		local op = buffer.readu8(instructions, ip)

		if op == opcodes.OP_CONSTANT then
			const_index = swap_endianess(buffer.readu16(instructions, ip + 1)) -- BE to LE
			ip += 2

			local err = push(constants[const_index + 1])
			if err then return err, stack, 0 end
		end

		ip += 1
	end

	return nil, stack, sp
end
