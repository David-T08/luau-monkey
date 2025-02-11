--!strict

export type Instruction = buffer
export type Opcode = number

local opcodes = table.freeze({
	OP_CONSTANT = 0x0,
	OP_ADD = 0x1,
	OP_POP = 0x2
})

local definitions = table.freeze({
	[opcodes.OP_CONSTANT] = {
		name = "OpConstant",
		widths = {2}
	},
	[opcodes.OP_ADD] = {
		name = "OpAdd",
		widths = {}
	},
	[opcodes.OP_POP] = {
		name = "OpPop",
		widths = {}
	}
})

local function swap_endianess(number: number): number
	local low = bit32.band(number, 0xFF)
	local high = bit32.band(bit32.rshift(number, 8), 0xFF)

	return bit32.bor(bit32.lshift(low, 8), high)
end

local function make(op: number, ...: number): Instruction
	local defined = definitions[op]
	if not defined then
		return buffer.create(0)
	end

	-- One byte for the opcode
	local instr_len = 1
	-- Add the widths of its operands
	for _, width in ipairs(defined.widths) do
		instr_len += width
	end

	local offset = 0
	local instruction = buffer.create(instr_len)
	buffer.writeu8(instruction, offset, op)
	offset += 1

	for index, operand in ipairs({...}) do
		local width = defined.widths[index]
		if width == 2 then
			buffer.writeu16(instruction, offset, swap_endianess(operand))
		end

		offset += width
	end

	return instruction
end

return {
	opcodes = opcodes,
	definitions = definitions,
	
	make = make
}