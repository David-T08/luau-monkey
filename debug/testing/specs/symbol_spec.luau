local symbol = require("../../../components/symbol")

local assert, it = require("../globals")
local format = require("../../format")

return {
	describe = "symbol",
	tests = {
		it("can define", function()
			local expected: { [string]: symbol.Symbol } = {
				["a"] = { index = 0, name = "a", scope = symbol.scopes.global },
				["b"] = { index = 1, name = "b", scope = symbol.scopes.global },
			}

			local global = { count = 0, store = {} } :: symbol.SymbolTable

			local a = symbol.define(global, "a")
			assert.are.same(a, expected.a)

			local b = symbol.define(global, "b")
			assert.are.same(b, expected.b)
		end),
	},
	it("can resolve", function()
		local global = { count = 0, store = {} } :: symbol.SymbolTable
		symbol.define(global, "a")
		symbol.define(global, "b")

		local expected: { [string]: symbol.Symbol } = {
			["a"] = { index = 0, name = "a", scope = symbol.scopes.global },
			["b"] = { index = 1, name = "b", scope = symbol.scopes.global },
		}

    for _, symbol in pairs(expected) do
      local resolved = global.store[symbol.name]
      assert.are.same(resolved, symbol.name, `Global store failed to resolve {symbol.name}, got {resolved}`)
    end
	end),
}
