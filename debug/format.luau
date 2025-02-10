--!strict
-- Formats a program into a string
local AST = require("../components/ast")
local object = require("../components/evaluator/object")

function statementToString(stmt: AST.Statement): string
	if stmt.node_type == AST.LET_STATEMENT then
		return `let {(stmt :: AST.LetStatement).name.value} = {expressionToString((stmt :: AST.LetStatement).value)}`
	elseif stmt.node_type == AST.RETURN_STATEMENT then
		return `return {expressionToString((stmt :: AST.ReturnStatement).return_value)}`
	elseif stmt.node_type == AST.EXPRESSION_STATEMENT then
		return expressionToString((stmt :: AST.ExpressionStatement).expression)
	elseif stmt.node_type == AST.ASSIGNMENT_STATEMENT then
		return `{(stmt :: AST.AssignmentStatement).name.value} = {expressionToString(
			(stmt :: AST.AssignmentStatement).value
		)}`
	elseif stmt.node_type == AST.ARRAY_INDEX_ASSIGNMENT_STATEMENT then
		local _stmt = stmt :: AST.ArrayIndexAssignmentStatement
		return `{expressionToString(_stmt.array)}[{expressionToString(_stmt.index)}] = {expressionToString(_stmt.value)}`
	elseif stmt.node_type == AST.BLOCK_STATEMENT then
		local out = {}

		for _, inner in ipairs((stmt :: AST.BlockStatement).statements) do
			table.insert(out, statementToString(inner))
		end

		return table.concat(out)
	end

	return `UNKNOWN STATEMENT??`
end

function expressionToString(expr: AST.Expression): string
	if
		expr.node_type == AST.BOOLEAN_LITERAL
		or expr.node_type == AST.STRING_LITERAL
		or expr.node_type == AST.INTEGER_LITERAL
		or expr.node_type == AST.IDENTIFIER
	then
		return `{(expr :: AST.IntegerLiteral).value}`
	elseif expr.node_type == AST.ARRAY_LITERAL then
		local out = {}
		for _, element in ipairs((expr :: AST.ArrayLiteral).elements) do
			table.insert(out, expressionToString(element))
		end
		return `[{table.concat(out, ", ")}]`
	elseif expr.node_type == AST.FUNCTION_LITERAL then
		local params = {}
		for _, element in ipairs((expr :: AST.FunctionLiteral).parameters) do
			table.insert(params, expressionToString(element))
		end
		return `fn({table.concat(params, ", ")}) \{{statementToString((expr :: AST.FunctionLiteral).body)}\}`
	elseif expr.node_type == AST.IF_EXPRESSION then
		local _expr = expr :: AST.IfExpression
		local out = { "if ", expressionToString(_expr.condition), " { ", statementToString(_expr.consequence) }

		if _expr.alternative then
			table.insert(out, ` } else \{ {statementToString(_expr.alternative)}`)
		end

		table.insert(out, " }")
		return table.concat(out)
	elseif expr.node_type == AST.CALL_EXPRESSION then
		local args = {}
		for _, element in ipairs((expr :: AST.CallExpression).arguments) do
			table.insert(args, expressionToString(element))
		end
		return `{expressionToString((expr :: AST.CallExpression).func)}({table.concat(args, ", ")})`
	elseif expr.node_type == AST.INDEX_EXPRESSION then
		return `({expressionToString((expr :: AST.IndexExpression).left)}[{expressionToString(
			(expr :: AST.IndexExpression).index
		)}])`
	elseif expr.node_type == AST.POST_INCREMENT_EXPRESSION then
		return `({expressionToString((expr :: AST.PostIncrementExpression).left)}{(expr :: AST.PostIncrementExpression).operator})`
	elseif expr.node_type == AST.PREFIX_EXPRESSION then
		return `({(expr :: AST.PrefixExpression).operator}{expressionToString((expr :: AST.PrefixExpression).right)})`
	elseif expr.node_type == AST.INFIX_EXPRESSION then
		return `({expressionToString((expr :: AST.InfixExpression).left)} {(expr :: AST.InfixExpression).operator} {expressionToString(
			(expr :: AST.InfixExpression).right
		)})`
	end

	return `UNKNOWN EXPRESSION??`
end

local function convertProgramToString(program: AST.Program)
	local str = {}

	for _, stmt in ipairs(program.statements) do
		table.insert(str, statementToString(stmt))
	end

	return table.concat(str)
end

local function format(what: AST.Program | object.BaseObject<unknown>, asTree: boolean?): string
	if (what :: any).node_type then
		return convertProgramToString(what :: AST.Program)
	elseif (what :: any).obj_type then
		local obj = what :: object.BaseObject<any>

		if
			obj.obj_type == object.kinds.BOOLEAN
			or obj.obj_type == object.kinds.STRING
			or obj.obj_type == object.kinds.NUMBER
			or obj.obj_type == object.kinds.ERROR
			or obj.obj_type == object.kinds.RETURN
		then
			return `{obj.value}`
		elseif obj.obj_type == object.kinds.ARRAY then
			local out = {}

			for _, v in ipairs(obj.value :: { object.BaseObject<unknown> }) do
				table.insert(out, format(v, asTree))
			end

			return `[{table.concat(out, ', ')}]`
		elseif obj.obj_type == object.kinds.BUILTIN_FUNCTION then
			return `builtin function`
		elseif obj.obj_type == object.kinds.FUNCTION then
			return `function`
		elseif obj.obj_type == object.kinds.NULL then
			return "NULL"
		end
	end

	return ""
end

return format
