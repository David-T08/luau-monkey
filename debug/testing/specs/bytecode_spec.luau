local bytecode = require("../../../components/bytecode")

local opcodes = bytecode.opcodes
local make = bytecode.make

local assert, it = require("../globals")
local format = require("../../format")

return {
	describe = "the bytecode",
	tests = {
		it("can make", function()
			-- Opcode, operands, expected
			local tests = {
				{ opcodes.OP_CONSTANT, { 65534 }, { opcodes.OP_CONSTANT, 255, 254 } },
				{ opcodes.OP_ADD, {}, {opcodes.OP_ADD}},
				{ opcodes.OP_POP, {}, {opcodes.OP_POP}}
			}

			for _, test in ipairs(tests) do
				local instruction = make(test[1], table.unpack(test[2]))

				assert.are_equal(
					buffer.len(instruction),
					#test[3],
					`Instruction has wrong length, got: $2, expected: $1`
				)

				for index, byte in ipairs(test[3]) do
					assert.are_equal(
						buffer.readu8(instruction, index - 1),
						byte,
						`\nWrong byte at 0x{string.format("%08X", index - 1)}, got: $1, expected: $2\n\n{format(instruction)}`
					)
				end
			end
		end),
	},
}
