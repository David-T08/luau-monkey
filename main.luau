local stdio = require("@lune/stdio")
local lexer = require("components/lexer")
local parser = require("components/parser")

local eval = require("components/evaluator/evaluator")
local object = require('components/evaluator/object')

local format = require("debug/format")

print("Monkey 0.1.0 RLPL")
local env = object.Environment.new()
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
	
	local evaluated = eval(program, env)
	if evaluated then
		print(format(evaluated))
	end
end