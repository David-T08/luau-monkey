local lex = require("../../../components/lexer")
local parse = require("../../../components/parser")
local AST = require("../../../components/ast")
local assert, it = require("../globals")

local format = require("../../format")
local stdio = require("@lune/stdio")

local NODE_TYPES = table.freeze({
	NODE = 0x0, -- ADDED
	STATEMENT = 0x1, -- ADDED
	EXPRESSION = 0x2,
	LET_STATEMENT = 0x3,
	RETURN_STATEMENT = 0x4,
	EXPRESSION_STATEMENT = 0x5,
	ASSIGNMENT_STATEMENT = 0x6,
	BLOCK_STATEMENT = 0x7,
	IDENTIFIER = 0x8,
	POST_INCREMENT_IDENTIFIER = 0x9,
	PREFIX_EXPRESSION = 0xA,
	INFIX_EXPRESSION = 0xB,
	INTEGER_LITERAL = 0xC,
	BOOLEAN_LITERAL = 0xD,
	FUNCTION_LITERAL = 0xE,
	IF_EXPRESSION = 0xF,
	CALL_EXPRESSION = 0x10,
	STRING_LITERAL = 0x11,
	ARRAY_LITERAL = 0x12,
	INDEX_EXPRESSION = 0x13,
	ARRAY_INDEX_EXPRESSION = 0x14,
	PROGRAM = 0x15,
})

local NODE_TYPES_STRINGS = table.freeze({
	[NODE_TYPES.NODE] = "NODE",
	[NODE_TYPES.STATEMENT] = "STATEMENT",
	[NODE_TYPES.EXPRESSION] = "EXPRESSION",
	[NODE_TYPES.LET_STATEMENT] = "LET_STATEMENT",
	[NODE_TYPES.RETURN_STATEMENT] = "RETURN_STATEMENT",
	[NODE_TYPES.EXPRESSION_STATEMENT] = "EXPRESSION_STATEMENT",
	[NODE_TYPES.ASSIGNMENT_STATEMENT] = "ASSIGNMENT_STATEMENT",
	[NODE_TYPES.BLOCK_STATEMENT] = "BLOCK_STATEMENT",
	[NODE_TYPES.IDENTIFIER] = "IDENTIFIER",
	[NODE_TYPES.POST_INCREMENT_IDENTIFIER] = "POST_INCREMENT_IDENTIFIER",
	[NODE_TYPES.PREFIX_EXPRESSION] = "PREFIX_EXPRESSION",
	[NODE_TYPES.INFIX_EXPRESSION] = "INFIX_EXPRESSION",
	[NODE_TYPES.INTEGER_LITERAL] = "INTEGER_LITERAL",
	[NODE_TYPES.BOOLEAN_LITERAL] = "BOOLEAN_LITERAL",
	[NODE_TYPES.FUNCTION_LITERAL] = "FUNCTION_LITERAL",
	[NODE_TYPES.IF_EXPRESSION] = "IF_EXPRESSION",
	[NODE_TYPES.CALL_EXPRESSION] = "CALL_EXPRESSION",
	[NODE_TYPES.STRING_LITERAL] = "STRING_LITERAL",
	[NODE_TYPES.ARRAY_LITERAL] = "ARRAY_LITERAL",
	[NODE_TYPES.INDEX_EXPRESSION] = "INDEX_EXPRESSION",
	[NODE_TYPES.ARRAY_INDEX_EXPRESSION] = "ARRAY_INDEX_EXPRESSION",
	[NODE_TYPES.PROGRAM] = "PROGRAM",
})

function expr_typeof(expr: AST.Node | any): string
	local typ = type(expr)

	if typ == "table" then
		if type(expr.node_type) == "number" then
			return NODE_TYPES_STRINGS[expr.node_type]
		end

		return expr.node_type
	end

	return typ
end

local function expect(what, expr, err_lvl)
	assert.are_equal(what, expr_typeof(expr), `Expected expression to be an {what}, got {expr_typeof(expr)}"`, err_lvl)
end

local function testLetStatement(stmt: AST.LetStatement, name)
	expect("LET_STATEMENT", stmt, 4)

	assert.are_equal(name, stmt.name.value)
end

local function testIntegerLiteral(expr: AST.IntegerLiteral, value: number)
	expect("INTEGER_LITERAL", expr, 4)

	assert.are_equal(value, expr.value, `Expected statement.expression.value to be {value}, got {expr.value}"`)
end

local function testIdentifier(expr, value)
	assert.are_equal(
		"IDENTIFIER",
		expr_typeof(expr),
		string.format("Expected expression to be an IDENTIFIER, got %s", expr_typeof(expr))
	)

	-- assert.are_equal(value, expr.value, `Expected expression.value to be {value}, got {expr.value}`)

	local expr: AST.Identifier = expr :: AST.Identifier

	assert.are_equal(
		value,
		expr.value,
		string.format("Expected expression.literal to be '%s', got %s", value, expr.value)
	)
end

local function testBooleanLiteral(expr, value)
	expect("BOOLEAN_LITERAL", expr, 3)

	local expr: AST.BooleanLiteral = expr :: AST.BooleanLiteral
end

local function TestLiteralExpression(expr: any, expected)
	local typ = type(expected)

	if typ == "number" then
		testIntegerLiteral(expr, expected)
	elseif typ == "string" then
		testIdentifier(expr, expected)
	elseif typ == "boolean" then
		testBooleanLiteral(expr, expected)
	end
end

local function TestInfixExpression(expr: AST.InfixExpression, left, operator, right)
	expect("INFIX_EXPRESSION", expr, 3)

	TestLiteralExpression(expr.left, left)

	assert.are_equal(
		operator,
		expr.operator,
		string.format("Expected statement.Expression.Operator to be %s, got %s", operator, expr.operator)
	)

	TestLiteralExpression(expr.right, right)
end

return {
	describe = "the parser",
	tests = {
		it("can do let statements", function()
			local inputs = {
				{ "let x = 5;", "x", 5 },
				{ "let y = 10;", "y", 10 },
				{ "let foobar = y;", "foobar", "y" },
			}

			for _, test in ipairs(inputs) do
				local program, errs = parse(lex(test[1]))

				assert.is.truthy(program, "Invalid Program!")
				assert.are_equal(1, #program.statements, "Expected 1 statement!")

				local stmt = program.statements[1]
				testLetStatement(stmt, test[2])

				TestLiteralExpression(stmt.value, test[3])
			end
		end),

		it("can detect incorrect let syntax", function()
			local input = [[
			let x 5
			let 838383;
		]]

			local program, errs = parse(lex(input))

			assert.are_equal(2, #errs, "Expected 2 errors, got " .. #errs .. "!")
		end),

		it("can handle returns", function()
			local input = [[
			return 5;
			return 10;
			return 993322;
		]]

			local program, errs = parse(lex(input))

			assert.is.truthy(program, "Invalid Program!")
			assert.are_equal(3, #program.statements, "Expected 3 statements!")

			for _, statement: AST.ReturnStatement in ipairs(program.statements) do
				expect("RETURN_STATEMENT", statement, 3)
			end
		end),

		it("can produce a basic AST", function()
			local program: AST.Program = { node_type = AST.PROGRAM, statements = {} }
			local ident1: AST.Identifier = {
				node_type = AST.IDENTIFIER,

				value = "myVar",
			}

			local ident2: AST.Identifier = {
				node_type = AST.IDENTIFIER,

				value = "anotherVar",
			}

			program.statements[1] = {
				node_type = AST.LET_STATEMENT,

				name = ident1,
				value = ident2,

				constant = false,
			} :: AST.LetStatement

			local produced = parse(lex("let myVar = anotherVar;"))
			assert.are_equal(program, produced)
		end),

		it("can do identifier expressions", function()
			local input = "foobar;"

			local program, errs = parse(lex(input))
			expect("PROGRAM", program, 3)

			assert.are_equal(1, #program.statements, "Expected 1 statement!")
			expect("EXPRESSION_STATEMENT", program.statements[1], 3)

			local statement: AST.ExpressionStatement = program.statements[1] :: AST.ExpressionStatement
			TestLiteralExpression(statement.expression, "foobar")
		end),

		it("can do integer literals", function()
			local input = "5;"

			local program = parse(lex(input))
			expect("PROGRAM", program, 3)
			assert.are_equal(1, #program.statements, "Expected 1 statement!")

			local statement: AST.ExpressionStatement = program.statements[1] :: AST.ExpressionStatement
			expect("EXPRESSION_STATEMENT", program.statements[1], 3)

			TestLiteralExpression(statement.expression, 5)
		end),

		it("can do prefix expressions", function()
			local tests = {
				{ "!5;", "!", 5 },
				{ "-15", "-", 15 },
				{ "!true", "!", true },
				{ "!false", "!", false },
			}

			for _, test in ipairs(tests) do
				local program = parse(lex(test[1]))

				assert.are_equal(1, #program.statements, "Expected 1 statement!")

				local statement: AST.ExpressionStatement = program.statements[1] :: AST.ExpressionStatement
				expect("EXPRESSION_STATEMENT", statement, 3)

				local pre_expr: AST.PrefixExpression = statement.expression :: AST.PrefixExpression
				expect("PREFIX_EXPRESSION", pre_expr, 3)

				assert.are_equal(
					test[2],
					pre_expr.operator,
					string.format("Expected statement.expression.operator to be %s, got %s", test[2], pre_expr.operator)
				)

				TestLiteralExpression(pre_expr.right, test[3])
			end
		end),

		it("can do basic infix expressions", function()
			local tests = {
				{ "5 + 5;", 5, "+", 5 },
				{ "5 - 5;", 5, "-", 5 },
				{ "5 * 5;", 5, "*", 5 },
				{ "5 / 5;", 5, "/", 5 },
				{ "5 > 5;", 5, ">", 5 },
				{ "5 < 5;", 5, "<", 5 },
				{ "5 == 5;", 5, "==", 5 },
				{ "5 != 5;", 5, "!=", 5 },
				{ "true == true", true, "==", true },
				{ "true != false", true, "!=", false },
				{ "false == false", false, "==", false },
			}

			for _, test in ipairs(tests) do
				local program, errs = parse(lex(test[1]))

				assert.are_equal(
					1,
					#program.statements,
					string.format(
						"Expected 1 statement, got %s! \nErrors: \n  %s\nProgram: \n%s\n",
						tostring(#program.statements),
						tostring(errs),
						tostring(program)
					)
				)

				expect("EXPRESSION_STATEMENT", program.statements[1], 3)

				local statement = program.statements[1] :: AST.ExpressionStatement

				TestInfixExpression(statement.expression, test[2], test[3], test[4])
			end
		end),

		it("can do advanced infix expressions", function()
			local tests = {
				{ "-a * b", "((-a) * b)" },
				{ "!-a", "(!(-a))" },
				{ "a + b + c", "((a + b) + c)" },
				{ "a + b - c", "((a + b) - c)" },
				{ "a * b * c", "((a * b) * c)" },
				{ "a * b / c", "((a * b) / c)" },
				{ "a + b / c", "(a + (b / c))" },
				{ "a + b * c + d / e - f", "(((a + (b * c)) + (d / e)) - f)" },
				{ "3 + 4; -5 * 5", "(3 + 4)((-5) * 5)" },
				{ "5 > 4 == 3 < 4", "((5 > 4) == (3 < 4))" },
				{ "5 < 4 != 3 > 4", "((5 < 4) != (3 > 4))" },
				{ "3 + 4 * 5 == 3 * 1 + 4 * 5", "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))" },
				{ "3 + 4 * 5 == 3 * 1 + 4 * 5", "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))" },
				{ "true", "true" },
				{ "false", "false" },
				{ "3 > 5 == false", "((3 > 5) == false)" },
				{ "3 < 5 == true", "((3 < 5) == true)" },
				{ "1 + (2 + 3) + 4", "((1 + (2 + 3)) + 4)" },
				{ "(5 + 5) * 2", "((5 + 5) * 2)" },
				{ "2 / (5 + 5)", "(2 / (5 + 5))" },
				{ "-(5 + 5)", "(-(5 + 5))" },
				{ "!(true == true)", "(!(true == true))" },
				{ "a + add(b * c) + d", "((a + add((b * c))) + d)" },
				{ "add(a, b, 1, 2 * 3, 4 + 5, add(6, 7 * 8))", "add(a, b, 1, (2 * 3), (4 + 5), add(6, (7 * 8)))" },
				{ "add(a + b + c * d / f + g)", "add((((a + b) + ((c * d) / f)) + g))" },
				{ "a * [1, 2, 3, 4][b * c] * d", "((a * ([1, 2, 3, 4][(b * c)])) * d)" },
				{ "add(a * b[2], b[1], 2 * [1, 2][1])", "add((a * (b[2])), (b[1]), (2 * ([1, 2][1])))" },
			}

			for _, test in ipairs(tests) do
				local program, errs = parse(lex(test[1]))

				expect("EXPRESSION_STATEMENT", program.statements[1], 3)
				assert.are_equal(format(program), test[2])
			end
		end),

		it("can do if statements", function()
			local input = "if (x < y) { x }"
			local program, errs = parse(lex(input))

			assert.are_equal(0, #errs, `Expected 0 errors, got {#errs}!\nErrors:\n{stdio.format(errs)}`)
			assert.are_equal(1, #program.statements, "Expected 1 program statement!")

			local stmt = program.statements[1]
			expect("EXPRESSION_STATEMENT", stmt)

			local expr = (stmt :: AST.ExpressionStatement).expression
			expect("IF_EXPRESSION", expr)

			local _expr = expr :: AST.IfExpression

			TestInfixExpression(_expr.condition, "x", "<", "y")

			assert.are_equal(1, #_expr.consequence.statements, "Expected 1 consequence statement!")

			local consequence = _expr.consequence.statements[1]
			expect("EXPRESSION_STATEMENT", consequence)

			testIdentifier(consequence.expression, "x")
		end),

		it("can do if else statements", function()
			local input = "if (x < y) { x } else { y }"
			local program, errs = parse(lex(input))

			assert.are_equal(0, #errs, `Expected 0 errors, got {#errs}!\nErrors:\n{stdio.format(errs)}`)
			assert.are_equal(1, #program.statements, "Expected 1 program statement!")

			local stmt = program.statements[1]
			expect("EXPRESSION_STATEMENT", stmt)

			local expr = (stmt :: AST.ExpressionStatement).expression
			expect("IF_EXPRESSION", expr)

			local _expr = expr :: AST.IfExpression

			TestInfixExpression(_expr.condition, "x", "<", "y")

			assert.are_equal(1, #_expr.consequence.statements, "Expected 1 consequence statement!")

			local consequence = _expr.consequence.statements[1] :: AST.ExpressionStatement
			expect("EXPRESSION_STATEMENT", consequence)

			testIdentifier(consequence.expression, "x")

			local alternative = _expr.alternative.statements[1] :: AST.ExpressionStatement
			expect("EXPRESSION_STATEMENT", alternative)

			testIdentifier(alternative.expression, "y")
		end),
	},
}
