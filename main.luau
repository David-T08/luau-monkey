local stdio = require("@lune/stdio")
local lexer = require("components/lexer")

print("Monkey 0.1.0 RLPL")
while true do
	local input = stdio.prompt("text", ">>")
	if input == "exit" then
		break
	end

	local start = os.clock()
	local token_types, literals = lexer(input)


	print(`Lexer took {os.clock() - start}s to lex {#input} characters; {#token_types} tokens`)

	for i = 1, #token_types do
		print(`    \{{token_types[i]}, {literals[i]}\}`)
	end
end