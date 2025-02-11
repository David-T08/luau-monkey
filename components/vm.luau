--!strict

local bytecode = require("bytecode")
local compile = require("compiler")
local object = require("evaluator/object")

local opcodes = bytecode.opcodes

local STACK_SIZE = 2048
local sp = 0

local constants: {object.BaseObject<unknown>} = {}
local stack: {object.BaseObject<unknown>} = {}

local function top(): object.BaseObject<unknown>?
	if sp == 0 then return end

	return stack[sp - 1]
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
			const_index = buffer.readu16(instructions, ip + 1)
			ip += 2

			local err = push(constants[const_index + 1])
			if err then return err, stack, 0 end
		end

		ip += 1
	end

	return nil, stack, sp
end
