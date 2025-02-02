--!strict
local tokens = require("tokens")
local AST = require("ast")
local stdio = require("@lune/stdio")

local constants = table.freeze({
	LOWEST = 0x0,
	EQUALS = 0x1,
	LESSGREATER = 0x2,
	SUM = 0x3,
	PRODUCT = 0x4,
	PREFIX = 0x5,
	CALL = 0x6,
	INDEX = 0x7,
})

local precedences = table.freeze({
	[tokens.EQ] = constants.EQUALS,
	[tokens.NOT_EQ] = constants.EQUALS,

	[tokens.LT] = constants.LESSGREATER,
	[tokens.GT] = constants.LESSGREATER,

	[tokens.PLUS] = constants.SUM,
	[tokens.MINUS] = constants.SUM,

	[tokens.DIV] = constants.PRODUCT,
	[tokens.MULT] = constants.PRODUCT,

	[tokens.LPAREN] = constants.CALL,
	[tokens.LBRACKET] = constants.INDEX,
})

type prefixParseFn = () -> AST.Expression?
type infixParseFn = (expr: AST.Expression) -> AST.Expression?

-- Most common variables here
-- Put them outside the function since it'd be painful to update and pass them in to EVERY function

local prefix_fns: {[number]: prefixParseFn} = {}
local infix_fns: {[number]: infixParseFn} = {}

-- Current token
local c_tok_type: number = nil
local c_tok_lit: string = nil

-- Peek token
local p_tok_type: number = nil
local p_tok_lit: string = nil

-- Token streams from lexer
local set_token_types: { number } = nil
local set_token_lits: { string } = nil

local errors = {}

local token_pos = 1
local max_token_pos = 1

local function next_token()
	if token_pos > max_token_pos + 1 then return end
	-- Set current token to peek token
	c_tok_type = p_tok_type
	c_tok_lit = p_tok_lit

	p_tok_type = set_token_types[token_pos]
	p_tok_lit = set_token_lits[token_pos]

	token_pos += 1
end

local function expect_peek(expected_tok_type: number): boolean
	if p_tok_type == expected_tok_type then
		next_token()
		return true
	else
		table.insert(errors, `Expected next token to be {expected_tok_type}, got {p_tok_type}`)
		return false
	end
end

function parse_expression(precedence: number): AST.Expression?
	local fn = prefix_fns[c_tok_type]

	if not fn then
		table.insert(errors, `No prefix parse function for {c_tok_type} found`)
		return
	end

	local left = fn()
	while p_tok_type ~= tokens.SEMICOLON and precedence < (precedences[p_tok_type] or constants.LOWEST) do
		local infix = infix_fns[p_tok_type]
		if not infix then
			return left
		end

		next_token()
		left = infix(left :: any)
	end

	return left
end

function parse_infix_expression(left: AST.Expression): AST.InfixExpression
	local start_tok_lit = c_tok_lit
	local precedence = precedences[c_tok_type] or constants.LOWEST
	next_token()

	return {
		node_type = AST.INFIX_EXPRESSION,

		literal = start_tok_lit,
		operator = start_tok_lit,

		left = left,
		-- TODO: Implement better error handling
		right = parse_expression(precedence) :: AST.Expression
	}
end

function parse_prefix_expression(): AST.PrefixExpression
	local start_tok_lit = c_tok_lit
	next_token()

	return {
		node_type = AST.PREFIX_EXPRESSION,

		literal = start_tok_lit,
		operator = start_tok_lit,

		right = parse_expression(constants.PREFIX) :: AST.Expression
	}
end

-- Literals
function parse_array_literal(): AST.ArrayLiteral
	local start_tok_lit = c_tok_lit

	return {
		node_type = AST.ARRAY_LITERAL,

		literal = start_tok_lit,
		elements = parse_expression_list(tokens.RBRACKET)
	}
end

function parse_string_literal(): AST.StringLiteral
	return {
		node_type = AST.STRING_LITERAL,

		value = c_tok_lit
	}
end

function parse_boolean_literal(): AST.BooleanLiteral
	return {
		node_type = AST.BOOLEAN_LITERAL,
		
		value = c_tok_type == tokens.TRUE
	}
end

function parse_integer_literal(): AST.IntegerLiteral?
	local int = tonumber(c_tok_lit)
	if not int then
		table.insert(errors, `Could not parse {c_tok_lit} as integer`)
		return
	end

	return {
		node_type = AST.INTEGER_LITERAL,

		value = int
	}
end

function parse_function_literal(): AST.FunctionLiteral?
	local start_tok_lit = c_tok_lit

	if not expect_peek(tokens.LPAREN) then
		return
	end
	local params = parse_function_parameters() :: { AST.Identifier }

	if not expect_peek(tokens.LBRACE) then
		return
	end

	return {
		node_type = AST.FUNCTION_LITERAL,

		literal = start_tok_lit,
		parameters = params,
		body = parse_block_statement(),
	}
end

-- Statements
function parse_let_statement(): AST.LetStatement?
	local start_tok_lit = c_tok_lit -- LET
	local is_const = p_tok_type == tokens.CONSTANT

	if is_const then
		next_token()
	end

	if not expect_peek(tokens.IDENT) then return end

	local ident_tok_lit = c_tok_lit
	if not expect_peek(tokens.ASSIGN) then return end

	next_token()

	local value = parse_expression(constants.LOWEST)
	if not value then return end
	while c_tok_type ~= tokens.SEMICOLON and c_tok_type ~= tokens.EOF do
		next_token()
	end

	local identifer: AST.Identifier = {
		node_type = AST.IDENTIFIER,
		value = ident_tok_lit,
		literal = ident_tok_lit
	}

	return {
		literal = start_tok_lit,
		node_type = AST.LET_STATEMENT,

		name = identifer,
		value = value,

		constant = is_const
	}

end

function parse_return_statement(): AST.ReturnStatement?
	local start_tok_lit = c_tok_lit
	next_token()

	local return_value = parse_expression(constants.LOWEST)
	if not return_value then return end

	while c_tok_type ~= tokens.SEMICOLON and c_tok_type ~= tokens.EOF do
		next_token()
	end

	return {
		node_type = AST.RETURN_STATEMENT,
		literal = start_tok_lit,

		return_value = return_value
	}
end

function parse_expression_statement(): AST.ExpressionStatement?
	local start_tok_lit = c_tok_lit

	local expr = parse_expression(constants.LOWEST)
	if not expr then return end

	local expr_stmt: AST.ExpressionStatement = {
		node_type = AST.EXPRESSION_STATEMENT,
		literal = start_tok_lit,
		expression = expr
	}

	if p_tok_type == tokens.SEMICOLON then
		next_token()
	end

	return expr_stmt
end

function parse_assignment_statement(): AST.AssignmentStatement?
	local start_tok_lit = c_tok_lit
	if not expect_peek(tokens.ASSIGN) then return end

	next_token()
	local value = parse_expression(constants.LOWEST)
	if not value then return end

	while c_tok_type ~= tokens.SEMICOLON and c_tok_type ~= tokens.EOF do
		next_token()
	end

	local identifier: AST.Identifier = {
		node_type = AST.IDENTIFIER,

		literal = start_tok_lit,
		value = start_tok_lit
	}

	return {
		node_type = AST.ASSIGNMENT_STATEMENT,

		name = identifier,
		value = value,

		literal = start_tok_lit
	}
end

function parse_block_statement(): AST.BlockStatement
	local start_tok_lit = c_tok_lit
	local statements: {AST.Statement} = {}

	next_token()
	while c_tok_type ~= tokens.RBRACE and c_tok_type ~= tokens.EOF do
		local statement: AST.Statement? = nil
		if c_tok_type == tokens.LET then
			statement = parse_let_statement()
		elseif c_tok_type == tokens.RETURN then
			statement = parse_return_statement()
		else
			if p_tok_type == tokens.ASSIGN then
				statement = parse_assignment_statement()
			else
				statement = parse_expression_statement()
			end
		end

		if statement then
			table.insert(statements, statement)
		end

		next_token()
	end

	return {
		node_type = AST.BLOCK_STATEMENT,

		statements = statements,
		literal = start_tok_lit
	}
end

function parse_array_index_assignment_statement(tok_lit: string, identifier: AST.Expression, index: AST.Expression): AST.ArrayAssignmentExpression?
	next_token()

	local value = parse_expression(constants.LOWEST)
	if not value then return end

	return {
		node_type = AST.ARRAY_INDEX_EXPRESSION,

		literal = c_tok_lit,
		index = index,
		array = identifier,
		value = value
	}
end

-- Expressions
function parse_grouped_expression(): AST.Expression?
	next_token()

	local expr = parse_expression(constants.LOWEST)

	if not expect_peek(tokens.RPAREN) then
		return
	end
	return expr
end

function parse_identifier(): AST.Identifier | AST.PostIncremementIdentifier
	if p_tok_type == tokens.INCREMENT or p_tok_type == tokens.DECREMENT then
		local start_tok_lit = c_tok_lit
		next_token()

		return {
			node_type = AST.POST_INCREMENT_IDENTIFIER,

			literal = start_tok_lit, -- The identifier
			operator = c_tok_lit, -- ++ or --
		} :: AST.PostIncremementIdentifier
	end

	return {
		node_type = AST.IDENTIFIER,
		literal = c_tok_lit
	} :: AST.Identifier
end

function parse_if_expression(): AST.IfExpression?
	local start_tok_lit = c_tok_lit
	if not expect_peek(tokens.LPAREN) then return end

	next_token()
	local condition = parse_expression(constants.LOWEST)
	if not condition then return end

	if not expect_peek(tokens.RPAREN) then return end
	if not expect_peek(tokens.LBRACE) then return end

	local consequence = parse_block_statement()
	local alternate: AST.BlockStatement?

	-- TODO, else if support
	if p_tok_type == tokens.ELSE then
		next_token() -- Skip ELSE

		if not expect_peek(tokens.LBRACE) then return end
		alternate = parse_block_statement()
	end

	return {
		node_type = AST.IF_EXPRESSION,

		literal = start_tok_lit,
		condition = condition,

		consequence = consequence,
		alternative = alternate
	}
end

function parse_index_expression(left: AST.Expression): AST.ArrayAssignmentExpression? | AST.IndexExpression?
	local start_tok_lit = c_tok_lit
	next_token()

	local index = parse_expression(constants.LOWEST)
	if not expect_peek(tokens.RBRACKET) or not index then return end

	if p_tok_type == tokens.ASSIGN then
		next_token()
		return parse_array_index_assignment_statement(start_tok_lit, left, index)
	end

	return {
		node_type = AST.INDEX_EXPRESSION,

		literal = start_tok_lit,
		left = left,
		index = index
	} :: AST.IndexExpression
end

function parse_expression_list(end_tok_type: number): {AST.Expression}
	local args = {}

	if p_tok_type == end_tok_type then
		next_token()
		return args
	end

	next_token()
	args[1] = parse_expression(constants.LOWEST) :: AST.Expression

	local pos = 2
	while p_tok_type == tokens.COMMA do
		next_token()
		next_token()

		args[pos] = parse_expression(constants.LOWEST) :: AST.Expression
		pos += 1
	end

	if not expect_peek(end_tok_type) then return {} end

	return args
end

function parse_function_parameters(): {AST.Identifier}
	local identifiers: {AST.Identifier} = {}

	-- (), no params
	if p_tok_type == tokens.RPAREN then
		next_token()
		return identifiers
	end

	next_token()
	identifiers[1] = {
		node_type = AST.IDENTIFIER,

		literal = c_tok_lit
	}

	local pos = 2

	while p_tok_type == tokens.COMMA do
		next_token() -- skip the comma
		next_token() -- read the identifier

		identifiers[pos] = {
			node_type = AST.IDENTIFIER,

			literal = c_tok_lit
		} :: AST.Identifier
		pos += 1
	end

	if not expect_peek(tokens.RPAREN) then return {} end
	return identifiers
end

function parse_call_expression(fn: AST.Expression): AST.CallExpression
	local start_tok_lit = c_tok_lit

	return {
		node_type = AST.CALL_EXPRESSION,

		func = fn,
		literal = start_tok_lit,
		arguments = parse_expression_list(tokens.RPAREN),
	}
end

prefix_fns = {
	[tokens.IDENT] = parse_identifier,
	[tokens.INT] = parse_integer_literal,
	[tokens.BANG] = parse_prefix_expression,
	[tokens.MINUS] = parse_prefix_expression,
	[tokens.INCREMENT] = parse_prefix_expression,
	[tokens.DECREMENT] = parse_prefix_expression,

	[tokens.IF] = parse_if_expression,
	[tokens.FUNCTION] = parse_function_literal,

	[tokens.TRUE] = parse_boolean_literal,
	[tokens.FALSE] = parse_boolean_literal,
	[tokens.STRING] = parse_string_literal,
	[tokens.LBRACKET] = parse_array_literal,

	[tokens.LPAREN] = parse_grouped_expression,
}

infix_fns = {
	[tokens.LPAREN] = parse_call_expression,
	[tokens.LBRACKET] = parse_index_expression,
}

for precedence, _ in pairs(precedences) do
	infix_fns[precedence] = parse_infix_expression
end

return function(token_types: { number }, token_literals: { string }): (AST.Program, {string})
	-- Reset global variables
	token_pos = 1
	max_token_pos = #token_types

	p_tok_type = nil :: any
	p_tok_lit = nil :: any

	set_token_types = token_types
	set_token_lits = token_literals

	errors = {}

	-- Set cur and peek tokens
	next_token()
	next_token()

	local statements: {AST.Statement} = {}

	-- Parse until EOF
	while c_tok_type ~= tokens.EOF do
		local statement: AST.Statement? = nil
		if c_tok_type == tokens.LET then
			statement = parse_let_statement()
		elseif c_tok_type == tokens.RETURN then
			statement = parse_return_statement()
		else
			if p_tok_type == tokens.ASSIGN then
				statement = parse_assignment_statement()
			else
				statement = parse_expression_statement()
			end
		end

		if statement then
			table.insert(statements, statement)
		end

		next_token()
	end

	return { node_type = AST.PROGRAM, statements = statements }, errors
end
