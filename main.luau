local stdio = require("@lune/stdio")
local lexer = require("components/lexer")
local parser = require("components/parser")

print("Monkey 0.1.0 RLPL")
while true do
	local input = stdio.prompt("text", ">>")
	if input == "exit" then
		break
	end

	local lex_t = os.clock()
	local token_types, literals = lexer(input)

	print(`Lexer took {os.clock() - lex_t}s to lex {#input} characters; {#token_types} tokens`)

	local parse_t = os.clock()

	local program, errs = parser(token_types, literals)
	print(`Parser took {os.clock() - parse_t}s to parse {#token_types} tokens`)

	if #errs > 0 then
		print(`Errors: \n  {table.concat(errs, "\n  ")}`)
	end
	
	print(stdio.format(program))
end