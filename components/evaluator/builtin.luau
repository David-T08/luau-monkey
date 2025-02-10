--!strict
local object = require("object")
local format = require("../../debug/format")

local function newError(str: string)
	return {
		obj_type = object.kinds.ERROR,
		value = str,
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
					value = len,
				}
			elseif argument.obj_type == object.kinds.ARRAY then
				return {
					obj_type = object.kinds.NUMBER,
					value = #(argument.value :: any),
				}
			end

			return newError(`expected {object.kinds.STRING}, got {argument.obj_type}`)
		end,
	},

	first = {
		obj_type = object.kinds.BUILTIN_FUNCTION,
		value = function(args: { object.BaseObject<unknown> }): object.BaseObject<unknown | string>
			if #args ~= 1 then
				return newError(`expected 1 argument, got {#args}`)
			end

			local arr = args[1] :: object.BaseObject<{ object.BaseObject<unknown> }>

			if arr.obj_type == object.kinds.ARRAY then
				local len = #arr.value
				if len > 0 then
					return arr.value[1]
				end
			end

			return newError(`expected {object.kinds.ARRAY}, got {arr.obj_type}`)
		end,
	},

	last = {
		obj_type = object.kinds.BUILTIN_FUNCTION,
		value = function(args: { object.BaseObject<unknown> }): object.BaseObject<unknown | string>
			if #args ~= 1 then
				return newError(`expected 1 argument, got {#args}`)
			end

			local arr = args[1] :: object.BaseObject<{ object.BaseObject<unknown> }>

			if arr.obj_type == object.kinds.ARRAY then
				local len = #arr.value
				if len > 0 then
					return arr.value[len]
				end

				return object.constants.null
			end

			return newError(`expected {object.kinds.ARRAY}, got {arr.obj_type}`)
		end,
	},

	rest = {
		obj_type = object.kinds.BUILTIN_FUNCTION,
		value = function(args: { object.BaseObject<unknown> }): object.BaseObject<unknown | string>
			if #args ~= 1 then
				return newError(`expected 1 argument, got {#args}`)
			end

			local arr = args[1] :: object.BaseObject<{ object.BaseObject<unknown> }>

			if arr.obj_type == object.kinds.ARRAY then
				local len = #arr.value
				if len > 0 then
					local cloned = table.clone(arr.value)
					table.remove(cloned, 1)

					return {
						obj_type = object.kinds.ARRAY,
						value = cloned,
					}
				end

				return object.constants.null
			end

			return newError(`expected {object.kinds.ARRAY}, got {arr.obj_type}`)
		end,
	},

	push = {
		obj_type = object.kinds.BUILTIN_FUNCTION,
		value = function(args: { object.BaseObject<unknown> }): object.BaseObject<unknown | string>
			if #args ~= 2 then
				return newError(`expected 2 argument, got {#args}`)
			end

			local arr = args[1] :: object.BaseObject<{ object.BaseObject<unknown> }>

			if arr.obj_type == object.kinds.ARRAY then
				local cloned = table.clone(arr.value)
				table.insert(cloned, args[2])

				return {
					obj_type = object.kinds.ARRAY,
					value = cloned,
				}
			end

			return newError(`expected {object.kinds.ARRAY}, got {arr.obj_type}`)
		end,
	},

	puts = {
		obj_type = object.kinds.BUILTIN_FUNCTION,
		value = function(args: { object.BaseObject<unknown> })
			for _, v in ipairs(args) do
				print(format(v))
			end
		end,
	},

	format = {
		obj_type = object.kinds.BUILTIN_FUNCTION,
		value = function(args: { object.BaseObject<unknown> })
			if #args ~= 1 then
				return newError(`expected 1 argument, got {#args}`)
			end
			return {
				obj_type = object.kinds.STRING,
				value = format(args[1]),
			}
		end,
	},

	clock = {
		obj_type = object.kinds.BUILTIN_FUNCTION,
		value = function()
			return {
				obj_type = object.kinds.NUMBER,
				value = os.clock()
			}
		end
	}
}
