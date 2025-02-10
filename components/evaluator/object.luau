local AST = require("../ast")

type EnvironmentValue = { value: BaseObject<unknown>, const: boolean }
type env_impl = {
	__index: env_impl,
	new: (outer: Environment?) -> Environment,

	set: <T>(self: Environment, key: string, value: T, const: boolean) -> T,

	-- Returns the value, and finally if it exists
	get: (self: Environment, key: string) -> (EnvironmentValue, boolean),
}

export type Environment = typeof(setmetatable(
	{} :: {
		store: { [string]: EnvironmentValue },
		outer: Environment?,

		obj_type: number,
	},
	{} :: env_impl
))

local Environment: env_impl = {} :: env_impl
Environment.__index = Environment

function Environment.new(outer)
	return setmetatable({
		store = {},
		outer = outer,
	}, Environment)
end

function Environment:get(key)
	local got = self.store[key]

	if got == nil and self.outer then
		got = self.outer:get(key)
	end

	return got, got ~= nil
end

function Environment:set<T>(key, value, const)
	self.store[key] = { value = value, const = const }

	return value
end

export type BaseObject<T> = {
	obj_type: number,
	value: T,
}

export type Function = {
	obj_type: number,

	body: AST.BlockStatement,
	params: {AST.Identifier},
	env: Environment
}

local kinds = table.freeze({
	STRING = 0x0,
	NUMBER = 0x1,
	BOOLEAN = 0x2,
	ERROR = 0x3,
	FUNCTION = 0x4,

	ARRAY = 0x5,
	RETURN = 0x6,
	NULL = 0x7,
	BUILTIN_FUNCTION = 0x8,
})

return {
	Environment = Environment,

	kinds = kinds,
	constants = {
		[true] = {
			obj_type = kinds.BOOLEAN,
			value = true,
		} :: BaseObject<boolean>,
		[false] = {
			obj_type = kinds.BOOLEAN,
			value = false,
		} :: BaseObject<boolean>,
		null = {
			obj_type = kinds.NULL,
			value = 'NULL'
		}
	},
}
