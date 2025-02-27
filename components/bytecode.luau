--!strict

export type Instruction = buffer
export type Opcode = number

local opcodes = table.freeze({
	OP_CONSTANT = 0x0,
	OP_POP = 0x1,

	OP_ADD = 0x2,
	OP_SUB = 0x3,
	OP_DIV = 0x4,
	OP_MUL = 0x5,

	OP_TRUE = 0x6,
	OP_FALSE = 0x7,

	 -- We dont need less than, since we can reorder code 1 < 2 -> 2 > 1
	OP_EQUAL = 0x8,
	OP_NOT_EQUAL = 0x9,
	OP_GREATER_THAN = 0xA,
	OP_GREATER_THAN_EQUAL = 0xB,
  
  OP_NEGATE = 0xC,
  OP_BANG = 0xD,

  OP_JMP = 0xE,
  OP_JMP_COND = 0xF,

  OP_NULL = 0x10,

  OP_SET_GLOBAL = 0x11,
  OP_GET_GLOBAL = 0x12
})

local definitions = table.freeze({
	[opcodes.OP_CONSTANT] = {
		name = "OpConstant",
		widths = {2}
	},
	[opcodes.OP_POP] = {
		name = "OpPop",
		widths = {}
	},

	[opcodes.OP_ADD] = {
		name = "OpAdd",
		widths = {}
	},
	[opcodes.OP_SUB] = {
		name = "OpSub",
		widths = {}
	},
	[opcodes.OP_DIV] = {
		name = "OpDiv",
		widths = {}
	},
	[opcodes.OP_MUL] = {
		name = "OpMul",
		widths = {}
	},

	[opcodes.OP_TRUE] = {
		name = "OpTrue",
		widths = {}
	},
	[opcodes.OP_FALSE] = {
		name = "OpFalse",
		widths = {}
	},

	[opcodes.OP_EQUAL] = {
		name = "OpEqual",
		widths = {}
	},
	[opcodes.OP_NOT_EQUAL] = {
		name = "OpNotEqual",
		widths = {}
	},
	[opcodes.OP_GREATER_THAN] = {
		name = "OpGreaterThan",
		widths = {}
	},
	[opcodes.OP_GREATER_THAN_EQUAL] = {
		name = "OpGreaterThanEqual",
		widths = {}
	},

  [opcodes.OP_NEGATE] = {
    name = "OpNegate",
    widths = {}
  },
  [opcodes.OP_BANG] = {
    name = "OpBang",
    widths = {}
  },

  [opcodes.OP_JMP] = {
    name = "OpJmp",
    widths = {2}
  },
  [opcodes.OP_JMP_COND] = {
    name = "OpJmpCond",
    widths = {2}
  },
  
  [opcodes.OP_NULL] = {
    name = "OpNull",
    widths = {}
  },

  [opcodes.OP_SET_GLOBAL] = {
    name = "OpSetGlobal",
    widths = {2}
  },
  [opcodes.OP_GET_GLOBAL] = {
    name = "OpGetGlobal",
    widths = {2}
  }
})

-- Monkey expects BE not LE, buffers dont let use write in a specific order like that
-- So bit shift to properly convert
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