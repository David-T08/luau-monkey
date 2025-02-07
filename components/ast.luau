--!strict
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
	POST_INCREMENT_EXPRESSION = 0x9,
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
	ARRAY_INDEX_ASSIGNMENT_STATEMENT = 0x14,
	HASH_LITERAL = 0x15,
	PROGRAM = 0x16,
})

local NODE_TYPES_STRINGS = table.freeze({
	NODE = "NODE",
	STATEMENT = "STATEMENT",
	EXPRESSION = "EXPRESSION",
	LET_STATEMENT = "LET_STATEMENT",
	RETURN_STATEMENT = "RETURN_STATEMENT",
	EXPRESSION_STATEMENT = "EXPRESSION_STATEMENT",
	ASSIGNMENT_STATEMENT = "ASSIGNMENT_STATEMENT",
	BLOCK_STATEMENT = "BLOCK_STATEMENT",
	IDENTIFIER = "IDENTIFIER",
	POST_INCREMENT_EXPRESSION = "POST_INCREMENT_EXPRESSION",
	PREFIX_EXPRESSION = "PREFIX_EXPRESSION",
	INFIX_EXPRESSION = "INFIX_EXPRESSION",
	INTEGER_LITERAL = "INTEGER_LITERAL",
	BOOLEAN_LITERAL = "BOOLEAN_LITERAL",
	FUNCTION_LITERAL = "FUNCTION_LITERAL",
	IF_EXPRESSION = "IF_EXPRESSION",
	CALL_EXPRESSION = "CALL_EXPRESSION",
	STRING_LITERAL = "STRING_LITERAL",
	ARRAY_LITERAL = "ARRAY_LITERAL",
	INDEX_EXPRESSION = "INDEX_EXPRESSION",
	ARRAY_INDEX_ASSIGNMENT_STATEMENT = "ARRAY_INDEX_ASSIGNMENT_STATEMENT",
	HASH_LITERAL = "HASH_LITERAL",
	PROGRAM = "PROGRAM",
})

export type Node = {node_type: number}

-- Statements
-- The _stmt field is never used, it is simply for the typechecker to realize Statement != Expression
export type Statement = Node & {_stmt: boolean?}

-- let const? name = value
export type LetStatement = Statement & {
	name: Identifier, -- {literal = "x"}
	value: Expression,
	constant: boolean
}

-- return value
export type ReturnStatement = Statement & {
	return_value: Expression,
}

export type ExpressionStatement = Statement & {
	expression: Expression
}

-- x = 2
export type AssignmentStatement = Statement & {
	name: Identifier,
	value: Expression
}

-- arr[index] = value
export type ArrayIndexAssignmentStatement = Statement & {
	array: Expression,
	index: Expression,
	value: Expression,
}

-- {statements}
export type BlockStatement = Statement & {
	statements: { Statement },
}

-- Expressions
-- The _expr field is never used, it is simply for the typechecker to realize Statement != Expression
export type Expression = Node & {_expr: boolean?}

-- foobar, xyz
export type Identifier = Expression & {
	value: string,
}

-- x++; x--;
export type PostIncrementExpression = Expression & {
	left: Expression,
	operator: string,
}

-- ++x; !true
export type PrefixExpression = Expression & {
	operator: string,
	right: Expression
}

-- x + a; "str" - "str"
export type InfixExpression = Expression & {
	left: Expression,
	operator: string,
	right: Expression,
}

-- Literal Expressions
-- 1,2,...
export type IntegerLiteral = Expression & {
	value: number
}

-- value
export type BooleanLiteral = Expression & {
	value: boolean,
}

-- "value"
export type StringLiteral = Expression & {
	value: string,
}

-- [elements]
export type ArrayLiteral = Expression	& {
	elements: {Expression}
}

-- {key: value}
export type HashLiteral = Expression & {
	pairs: {[Expression]: Expression}
}

-- fn(params) {body}
export type FunctionLiteral = Expression & {
	parameters: { Identifier },
	body: BlockStatement,
}

-- if (cond) {consequence} else {alternative}
export type IfExpression = Expression & {
	condition: Expression,

	consequence: BlockStatement,
	alternative: BlockStatement?
}

-- call(args)
export type CallExpression = Expression & {
	func: Expression,
	arguments: {Expression},
}

-- arr[index]
export type IndexExpression = Expression & {
	left: Expression,
	index: Expression
}

-- Program
export type Program = Node & {
	statements: {Statement}
}

return NODE_TYPES