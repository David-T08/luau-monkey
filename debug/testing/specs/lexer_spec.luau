local tokens = require("../../../components/tokens")
local lex = require("../../../components/lexer")

local assert, it = require("../globals")

return {
	describe = "the lexer",
	tests = {
		it("can do basic symbols", function()
			local input = "=+(){},;"
			local expected = {
				{ tokens.ASSIGN, "=" },
				{ tokens.PLUS, "+" },
				{ tokens.LPAREN, "(" },
				{ tokens.RPAREN, ")" },
				{ tokens.LBRACE, "{" },
				{ tokens.RBRACE, "}" },
				{ tokens.COMMA, "," },
				{ tokens.SEMICOLON, ";" },
				{ tokens.EOF, "" },
			}

			local types, literals = lex(input)
			for i, literal in ipairs(literals) do
				local tok_type = types[i]

				assert.are.same({ tok_type, literal }, expected[i])
			end
		end),

		it("can do a basic program", function()
			local input = [[let five = 5;
    let ten = 10;

    let add = fn(x, y) {
      x + y;
    };

    let result = add(five, ten);
    ]]
			local expected = {
				{ tokens.LET, "let" },
				{ tokens.IDENT, "five" },
				{ tokens.ASSIGN, "=" },
				{ tokens.INT, "5" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.LET, "let" },
				{ tokens.IDENT, "ten" },
				{ tokens.ASSIGN, "=" },
				{ tokens.INT, "10" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.LET, "let" },
				{ tokens.IDENT, "add" },
				{ tokens.ASSIGN, "=" },
				{ tokens.FUNCTION, "fn" },
				{ tokens.LPAREN, "(" },
				{ tokens.IDENT, "x" },
				{ tokens.COMMA, "," },
				{ tokens.IDENT, "y" },
				{ tokens.RPAREN, ")" },
				{ tokens.LBRACE, "{" },
				{ tokens.IDENT, "x" },
				{ tokens.PLUS, "+" },
				{ tokens.IDENT, "y" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.RBRACE, "}" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.LET, "let" },
				{ tokens.IDENT, "result" },
				{ tokens.ASSIGN, "=" },
				{ tokens.IDENT, "add" },
				{ tokens.LPAREN, "(" },
				{ tokens.IDENT, "five" },
				{ tokens.COMMA, "," },
				{ tokens.IDENT, "ten" },
				{ tokens.RPAREN, ")" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.EOF, "" },
			}

			local types, literals = lex(input)
			for i, literal in ipairs(literals) do
				local tok_type = types[i]

				assert.are.same({ tok_type, literal }, expected[i])
			end
		end),

		it("can do operators", function()
			local input = [[
      !-/*5;
      5 < 10 > 5;
		]]
			local expected = {
				{ tokens.BANG, "!" },
				{ tokens.MINUS, "-" },
				{ tokens.DIV, "/" },
				{ tokens.MULT, "*" },
				{ tokens.INT, "5" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.INT, "5" },
				{ tokens.LT, "<" },
				{ tokens.INT, "10" },
				{ tokens.GT, ">" },
				{ tokens.INT, "5" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.EOF, "" },
			}

			local types, literals = lex(input)
			for i, literal in ipairs(literals) do
				local tok_type = types[i]

				assert.are.same({ tok_type, literal }, expected[i])
			end
		end),

		it("can do a basic if statement", function()
			local input = [[
    if (5 < 10) {
      return true;
    } else {
      return false;
    }
    ]]
			local expected = {
				{ tokens.IF, "if" },
				{ tokens.LPAREN, "(" },
				{ tokens.INT, "5" },
				{ tokens.LT, "<" },
				{ tokens.INT, "10" },
				{ tokens.RPAREN, ")" },
				{ tokens.LBRACE, "{" },
				{ tokens.RETURN, "return" },
				{ tokens.TRUE, "true" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.RBRACE, "}" },
				{ tokens.ELSE, "else" },
				{ tokens.LBRACE, "{" },
				{ tokens.RETURN, "return" },
				{ tokens.FALSE, "false" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.RBRACE, "}" },
				{ tokens.EOF, "" },
			}

			local types, literals = lex(input)
			for i, literal in ipairs(literals) do
				local tok_type = types[i]

				assert.are.same({ tok_type, literal }, expected[i])
			end
		end),

		it("can do pre increment/decrement operators", function()
			local input = "x++; --x; x--; ++x"

			local expected = {
				{ tokens.IDENT, "x" },
				{ tokens.INCREMENT, "++" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.DECREMENT, "--" },
				{ tokens.IDENT, "x" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.IDENT, "x" },
				{ tokens.DECREMENT, "--" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.INCREMENT, "++" },
				{ tokens.IDENT, "x" },
				{ tokens.EOF, "" }
			}

			local types, literals = lex(input)
			for i, literal in ipairs(literals) do
				local tok_type = types[i]

				assert.are.same({ tok_type, literal }, expected[i])
			end
		end),

		it("can fully lex", function()
			local input = [[
    10 == 10;
    10 != 9;
	"foobar"
	" foo  bar"
	"I have nested quotes! \"omggg\""
	[1, 2];
	{"foo": "bar", "test": 1}
	{1: 2};
	let const x = 5
    ]]
			local expected = {
				{ tokens.INT, "10" },
				{ tokens.EQ, "==" },
				{ tokens.INT, "10" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.INT, "10" },
				{ tokens.NOT_EQ, "!=" },
				{ tokens.INT, "9" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.STRING, "foobar" },
				{ tokens.STRING, " foo  bar" },
				{ tokens.STRING, 'I have nested quotes! "omggg"' },
				{ tokens.LBRACKET, "[" },
				{ tokens.INT, "1" },
				{ tokens.COMMA, "," },
				{ tokens.INT, "2" },
				{ tokens.RBRACKET, "]" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.LBRACE, "{" },
				{ tokens.STRING, "foo" },
				{ tokens.COLON, ":" },
				{ tokens.STRING, "bar" },
				{ tokens.COMMA, "," },
				{ tokens.STRING, "test" },
				{ tokens.COLON, ":" },
				{ tokens.INT, "1" },
				{ tokens.RBRACE, "}" },
				{ tokens.LBRACE, "{" },
				{ tokens.INT, "1" },
				{ tokens.COLON, ":" },
				{ tokens.INT, "2" },
				{ tokens.RBRACE, "}" },
				{ tokens.SEMICOLON, ";" },
				{ tokens.LET, "let" },
				{ tokens.CONSTANT, "const" },
				{ tokens.IDENT, "x" },
				{ tokens.ASSIGN, "=" },
				{ tokens.INT, "5" },
				{ tokens.EOF, "" },
			}

			local types, literals = lex(input)
			for i, literal in ipairs(literals) do
				local tok_type = types[i]

				assert.are.same({ tok_type, literal }, expected[i])
			end
		end),
	},
}
