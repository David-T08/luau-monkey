--!strict
local tokens = require("tokens")

local insert = table.insert
local concat = table.concat

-- Optimizing comparisons
-- Strings are more expensive than numbers
local C_SPACE = string.byte(" ")
local C_TAB = string.byte("\t")
local C_NEWLINE = string.byte("\n")
local C_RETURN = string.byte("\r")

local C_EQUALS = string.byte("=")
local C_PLUS = string.byte("+")
local C_MINUS = string.byte("-")
local C_BANG = string.byte("!")

local C_BACKSLASH = string.byte("\\")
local C_SQUOTE = string.byte("'")
local C_DQUOTE = string.byte("\"")

-- Lookup tables
local operators = table.freeze({
	-- Math
	[C_MINUS] = tokens.MINUS,
	[C_PLUS] = tokens.PLUS,
	[string.byte("*")] = tokens.MULT,
	[string.byte("/")] = tokens.DIV,

	-- Comparison/Assignment
	[C_EQUALS] = tokens.ASSIGN,
	[string.byte(":")] = tokens.COLON,
	[C_BANG] = tokens.BANG,
	[string.byte("<")] = tokens.LT,
	[string.byte(">")] = tokens.GT,

	-- Seperators
	[string.byte(";")] = tokens.SEMICOLON,
	[string.byte(",")] = tokens.COMMA,

	-- Parenthesis
	[string.byte("(")] = tokens.LPAREN,
	[string.byte(")")] = tokens.RPAREN,

	-- Braces
	[string.byte("{")] = tokens.LBRACE,
	[string.byte("}")] = tokens.RBRACE,

	-- Brackets
	[string.byte("[")] = tokens.LBRACKET,
	[string.byte("]")] = tokens.RBRACKET,
})


local keywords = table.freeze({
	["fn"] = tokens.FUNCTION,
	["let"] = tokens.LET,
	["true"] = tokens.TRUE,
	["false"] = tokens.FALSE,
	["if"] = tokens.IF,
	["else"] = tokens.ELSE,
	["return"] = tokens.RETURN,
	["for"] = tokens.FOR,
	["const"] = tokens.CONSTANT,
})

-- Returns the read character, new read_position, and the read characters ASCII code
local function read_char(input: string, read_pos: number, str_length: number): (string, number, number)
	if read_pos >= str_length + 1 then
		return "", read_pos + 1, 0
	end

	local read = input:sub(read_pos, read_pos)
	return read, read_pos + 1, read:byte()
end

-- Returns the peeked character's ASCII code
local function peek_char(input: string, read_pos: number, str_length: number): number
	if read_pos >= str_length + 1 then
		return 0
	end
	
	return input:sub(read_pos, read_pos):byte()
end

-- Returns 2 token streams, the first being the types, second being the literals
-- Each go in order, so types[1] correlates to literals[1]
return function(input: string): ({number}, {string})
	local types = {}
	local literals = {}

	local read_pos = 2
	local cur_char = input:sub(1,1)
	local cur_byte = cur_char:byte()
	local next_byte = 0

	-- Calculate only once, for out of bounds checking read_char
	local length = #input

	while true do
		local token_type = tokens.ILLEGAL
		local token_literal = ""
		
		-- Skip whitespace
		while cur_byte == C_SPACE or cur_byte == C_TAB or cur_byte == C_NEWLINE or cur_byte == C_RETURN do
			cur_char, read_pos, cur_byte = read_char(input, read_pos, length)
		end

		local operator_type = operators[cur_byte]
		if operator_type then -- Operators
			local double = true -- To check if we peeked, so we can read at the end
			next_byte = peek_char(input, read_pos, length)

			if cur_byte == C_EQUALS and next_byte == C_EQUALS then
				token_type, token_literal = tokens.EQ, "=="
			elseif cur_byte == C_BANG and next_byte == C_EQUALS then
				token_type, token_literal = tokens.NOT_EQ, "!="
			elseif cur_byte == C_PLUS and next_byte == C_PLUS then
				token_type, token_literal = tokens.INCREMENT, "++"
			elseif cur_byte == C_MINUS and next_byte == C_MINUS then
				token_type, token_literal = tokens.DECREMENT, "--"
			else
				double = false
				token_type, token_literal = operator_type, cur_char
			end

			-- If we peeked and made a token (EQ, NOT_EQ, INCREMENT, DECREMENT), make sure we read that peeked char now
			if double then
				cur_char, read_pos, cur_byte = read_char(input, read_pos, length)
			end
		elseif cur_byte == 0 then -- EOF
			insert(types, tokens.EOF)
			insert(literals, '')
			break
		elseif cur_byte == C_SQUOTE or cur_byte == C_DQUOTE then -- Strings
			local str = {}
			local escaped = false
			local starting_quote = cur_byte

			while true do
				cur_char, read_pos, cur_byte = read_char(input, read_pos, length)

				if (not escaped and cur_byte == starting_quote) or cur_byte == 0 then
					break
				end

				next_byte = peek_char(input, read_pos, length)
				if cur_byte == C_BACKSLASH and (next_byte == C_SQUOTE or next_byte == C_DQUOTE) then
					escaped = true
				else
					insert(str, cur_char)
					escaped = false
				end
			end

			token_type, token_literal = tokens.STRING, concat(str)

		else -- Idents, Ints, Illegal
			-- Alphabetic [a-zA-Z_]
			if (cur_byte >= 65 and cur_byte <= 90) or (cur_byte >= 97 and cur_byte <= 122) or (cur_byte == 95) then
				local start = read_pos - 1
				
				while true do
					cur_char, read_pos, cur_byte = read_char(input, read_pos, length)
					if not ((cur_byte >= 65 and cur_byte <= 90) or (cur_byte >= 97 and cur_byte <= 122) or (cur_byte == 95)) then 
						break 
					end
				end

				local literal = input:sub(start, read_pos-2)
				insert(types, keywords[literal] or tokens.IDENT)
				insert(literals, literal)

				continue
			elseif (cur_byte >= 48 and cur_byte <= 57) then -- Numeric [0-9]
				local start = read_pos - 1

				while true do
					cur_char, read_pos, cur_byte = read_char(input, read_pos, length)
					if not (cur_byte >= 48 and cur_byte <= 57) then
						break
					end
				end

				insert(types, tokens.INT)
				insert(literals, input:sub(start, read_pos-2))

				continue
			else
				token_type, token_literal = tokens.ILLEGAL, cur_char
			end
		end

		insert(types, token_type)
		insert(literals, token_literal)
		
		cur_char, read_pos, cur_byte = read_char(input, read_pos, length)
	end

	return types, literals
end
