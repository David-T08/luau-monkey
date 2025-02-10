--!strict
local object = require("object")

local function newError(str: string)
	return {
		obj_type = object.kinds.ERROR,
		value = str
	}
end

return {
	len = {
		obj_type = object.kinds.BUILTIN_FUNCTION,
		value = function(args: { object.BaseObject<unknown> }): object.BaseObject<number | string>
			if #args ~= 1 then
				return newError(`expected 1 argument, got {#args}`)
			end

			local argument = args[1]

			if argument.obj_type == object.kinds.STRING then
				---@cast argument String
				local len = string.len((argument :: object.BaseObject<string>).value)

				return {
					obj_type = object.kinds.NUMBER,
					value = len
				}
			end

			return newError(`expected {object.kinds.STRING}, got {argument.obj_type}`)
		end,
	},
}
