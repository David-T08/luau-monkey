--!strict

local Symbol = {}

local scopes = table.freeze({
  global = 0x0
})

export type Symbol = {
  name: string,
  scope: number,
  index: number
}

export type SymbolTable = {
  store: {[string]: Symbol},
  count: number
}

function Symbol.define(store: SymbolTable, name: string): Symbol
  local symbol: Symbol = {
    name = name,
    index = store.count,
    scope = scopes.global
  }

  store.count += 1
  store.store[name] = symbol

  return symbol
end

Symbol.scopes = scopes
return Symbol