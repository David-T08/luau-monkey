--!strict
local stdio = require("@lune/stdio")
local globals = {}

-- https://stackoverflow.com/questions/25922437/how-can-i-deep-compare-2-lua-tables-which-may-or-may-not-have-tables-as-keys
local function table_eq(table1, table2)
	local avoid_loops = {}
	local function recurse(t1, t2)
		-- compare value types
		if type(t1) ~= type(t2) then
			return false
		end
		-- Base case: compare simple values
		if type(t1) ~= "table" then
			return t1 == t2
		end
		-- Now, on to tables.
		-- First, let's avoid looping forever.
		if avoid_loops[t1] then
			return avoid_loops[t1] == t2
		end
		avoid_loops[t1] = t2
		-- Copy keys from t2
		local t2keys = {}
		local t2tablekeys = {}
		for k, _ in pairs(t2) do
			if type(k) == "table" then
				table.insert(t2tablekeys, k)
			end
			t2keys[k] = true
		end
		-- Let's iterate keys from t1
		for k1, v1 in pairs(t1) do
			local v2 = t2[k1]
			if type(k1) == "table" then
				-- if key is a table, we need to find an equivalent one.
				local ok = false
				for i, tk in ipairs(t2tablekeys) do
					if table_eq(k1, tk :: any) and recurse(v1, t2[tk]) then
						table.remove(t2tablekeys, i)
						t2keys[tk] = nil
						ok = true
						break
					end
				end
				if not ok then
					return false
				end
			else
				-- t1 has a key which t2 doesn't have, fail.
				if v2 == nil then
					return false
				end
				t2keys[k1] = nil
				if not recurse(v1, v2) then
					return false
				end
			end
		end
		-- if t2 has a key which t1 doesn't have, fail.
		if next(t2keys) then
			return false
		end
		return true
	end
	return recurse(table1 :: any, table2 :: any)
end

globals.are = {
	same = function(got, expected)
		local result = table_eq(got, expected)

		local file, line = debug.info(2, "sl")
		file = file:match(`%[string "([%w%._/]+)"]`)

		print(file, line)

		if not result then
			error(`[!!FAILURE!!][!!{file}!!{line}!!]Expected objects to be the same.\nExpected: ({tostring(expected)}) {stdio.format(expected)}\nPassed In: ({tostring(got)}) {stdio.format(got)}`)
		end
	end
}

-- Assert, It
return globals, function(label: string, callback: () -> ())
	return {
		label = label,

		callback = callback
	}
end