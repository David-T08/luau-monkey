local stdio = require("@lune/stdio")
local lexer = require("components/lexer")
local parser = require("components/parser")

local compile = require("components/compiler")
local vm = require("components/vm")

local format = require("debug/format")

print("Monkey 0.6.0 REPL")

local constants = {}
local globals = {}
local symbol_table = {count = 0, store = {}}

while true do
	local input = stdio.prompt("text", ">>")
	if input == "exit" then
		break
	end

	local lex_t = os.clock()
	local token_types, literals = lexer(input)

	-- print(`Lexer took {os.clock() - lex_t}s to lex {#input} characters; {#token_types} tokens`)
	for i = 1, #token_types do
		-- print(`\{literal: {literals[i]}, type: {token_types[i]}\}`)
	end

	local parse_t = os.clock()

	local program, errs = parser(token_types, literals)
	-- print(`Parser took {os.clock() - parse_t}s to parse {#token_types} tokens`)

	if #errs > 0 then
		print(`Errors: \n  {table.concat(errs, "\n  ")}`)
	end
	
	local c_err, compiled = compile(program, false, symbol_table, constants)
	if c_err then
		print(`Compilation failed: {c_err}`)
		continue
	end
  constants = compiled.constants  
  print(compiled.constants)

	local debug_constants = {}
	for i, const in ipairs(constants) do
		table.insert(debug_constants, `[{i}] = {format(const)}`)
	end
	print(`Compiled:\n{format(compiled.instructions)}\n\nConstants:\n {table.concat(debug_constants, '\n ')}\n`)

	local vm_err, stack_top = vm(constants, compiled.instructions, false, globals)
	if vm_err then
		print(`VM failed: {vm_err}`)
		continue
	end

	print(`Stack top: {format(stack_top)}`)
end