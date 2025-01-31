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
	PROGRAM = 0x15
})

export type Node = {node_type: number}

-- Statements
export type Statement = Node & {}

export type LetStatement = Statement & {
	literal: string,
	name: Identifier,
	value: Expression,
	constant: boolean
}

export type ReturnStatement = Statement & {
	literal: string,
	return_value: Expression,
}

export type ExpressionStatement = Statement & {
	literal: string,
	expression: Expression
}

export type AssignmentStatement = Statement & {
	literal: string,
	name: Identifier,
	value: Expression
}

export type BlockStatement = Statement & {
	literal: string,
	statements: { Statement },
}

-- Expressions
export type Expression = Node & {}

export type Identifier = Expression & {
	literal: string,
	value: string
}

export type PostIncremementIdentifier = Expression & {
	literal: string,
	operator: string,

	value: string,
}

export type PrefixExpression = Expression & {
	literal: string,
	operator: string,
	right: Expression
}

export type InfixExpression = Expression & {
	literal: string,
	left: Expression,
	operator: string,
	right: Expression,
}

-- Literal Expressions
export type IntegerLiteral = Expression & {
	literal: string,
	value: number
}

export type BooleanLiteral = Expression & {
	literal: string,
	value: boolean,
}

export type FunctionLiteral = Expression & {
	literal: string,
	parameters: { Identifier },
	body: BlockStatement,
}

export type ArrayLiteral = Expression	& {
	literal: string,
	elements: {Expression}
}

export type IfExpression = Expression & {
	literal: string,
	condition: Expression,

	consequence: BlockStatement,
	alternative: BlockStatement?
}

export type CallExpression = Expression & {
	literal: string,
	func: Expression,
	arguments: {Expression},
}

export type StringLiteral = Expression & {
	literal: string,
	value: string,
}

export type IndexExpression = Expression & {
	literal: string,
	left: Expression,
	index: Expression
}

export type ArrayIndexExpression = Expression & {
	literal: string,
	array: Expression,
	index: Expression,
	value: Expression
}

-- Program
export type Program = Node & {
	statements: {Statement}
}

return NODE_TYPES