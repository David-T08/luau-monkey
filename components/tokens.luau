local optimized_tokens = table.freeze({
	ILLEGAL = 0x0,
	EOF = 0x1,

	IDENT = 0x2, -- add, foobar, x, y,...
	INT = 0x3, -- 13,5,53

	-- operators
	ASSIGN = 0x4,
	PLUS = 0x5,
	MINUS = 0x6,
	MULT = 0x7,
	DIV = 0x8,
	BANG = 0x9,

	LT = 0xA,
	GT = 0xB,

	COMMA = 0xC,
	SEMICOLON = 0xD,
	COLON = 0xE,

	LPAREN = 0xF,
	RPAREN = 0x10,
	LBRACE = 0x11,
	RBRACE = 0x12,

	LBRACKET = 0x13,
	RBRACKET = 0x14,

	FOR = 0x15,

	FUNCTION = 0x16,
	LET = 0x17,
	TRUE = 0x18,
	FALSE = 0x19,
	IF = 0x1A,
	ELSE = 0x1B,
	RETURN = 0x1C,
	CONSTANT = 0x1D,

	EQ = 0x1E,
	NOT_EQ = 0x1F,

	INCREMENT = 0x20,
	DECREMENT = 0x21,

	STRING = 0x22,
	OCTAL_INT = 0x23,
	BINARY_INT = 0x24,
	HEX_INT = 0x25
})

-- Simply for printing tokens, to easier understand
-- For debugging only
local debug_tokens = table.freeze({
	ILLEGAL = "ILLEGAL",
	EOF = "EOF",

	IDENT = "IDENT", -- add, foobar, x, y,...
	INT = "INT", -- 13,5,53

	-- operators
	ASSIGN = "ASSIGN",
	PLUS = "PLUS",
	MINUS = "MINUS",
	MULT = "MULT",
	DIV = "DIV",
	BANG = "BANG",

	LT = "LT",
	GT = "GT",

	COMMA = "COMMA",
	SEMICOLON = "SEMICOLON",
	COLON = "COLON",

	LPAREN = "LPAREN",
	RPAREN = "RPAREN",
	LBRACE = "LBRACE",
	RBRACE = "RBRACE",

	LBRACKET = "LBRACKET",
	RBRACKET = "RBRACKET",

	FOR = "FOR",

	FUNCTION = "FUNCTION",
	LET = "LET",
	TRUE = "TRUE",
	FALSE = "FALSE",
	IF = "IF",
	ELSE = "ELSE",
	RETURN = "RETURN",
	CONSTANT = "CONSTANT",

	EQ = "EQ",
	NOT_EQ = "NOT_EQ",

	INCREMENT = "INCREMENT",
	DECREMENT = "DECREMENT",

	STRING = "STRING",
	OCTAL_INT = "OCTAL_INT",
	BINARY_INT = "BINARY_INT",
	HEX_INT = "HEX_INT"
})

return optimized_tokens
