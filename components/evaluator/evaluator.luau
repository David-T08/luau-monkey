--!strict

local object = require("object")
local AST = require("../ast")

local builtin = require("builtin")

function eval_prefix_expression(right: object.BaseObject<unknown>, operator: string): object.BaseObject<unknown>
	if operator == "!" then
		if right == object.constants[true] then
			return object.constants[false]
		elseif right == object.constants[false] or right == object.constants.null then
			return object.constants[true]
		end

		return object.constants[false]
	elseif operator == "-" then
		if right.obj_type ~= object.kinds.NUMBER then
			return {
				obj_type = object.kinds.ERROR,
				value = `unknown operator: -{right.obj_type}`,
			}
		end

		return {
			obj_type = object.kinds.NUMBER,
			value = -(right :: object.BaseObject<number>).value,
		}
	end

	return {
		obj_type = object.kinds.ERROR,
		value = `unknown operator: {operator}{right.obj_type}`,
	}
end

function eval_string_infix_expression(
	left: object.BaseObject<string>,
	operator: string,
	right: object.BaseObject<string>
): object.BaseObject<unknown>
	if operator == "+" then
		return {
			obj_type = object.kinds.STRING,
			value = left.value .. right.value,
		}
	elseif operator == "==" then
		return object.constants[left.value == right.value]
	elseif operator == "~=" then
		return object.constants[left.value ~= right.value]
	end

	return {
		obj_type = object.kinds.ERROR,
		value = `unknown operator: {left.obj_type} {operator} {right.obj_type}`,
	}
end

function eval_number_infix_expression(
	left: object.BaseObject<number>,
	operator: string,
	right: object.BaseObject<number>
): object.BaseObject<unknown>
	-- Arithmitic
	if operator == "+" then
		return {
			obj_type = object.kinds.NUMBER,
			value = left.value + right.value,
		}
	elseif operator == "-" then
		return {
			obj_type = object.kinds.NUMBER,
			value = left.value - right.value,
		}
	elseif operator == "/" then
		return {
			obj_type = object.kinds.NUMBER,
			value = left.value / right.value,
		}
	elseif operator == "*" then
		return {
			obj_type = object.kinds.NUMBER,
			value = left.value * right.value,
		}
	end

	-- Comparisons
	if operator == "<" then
		return object.constants[left.value < right.value]
	elseif operator == ">" then
		return object.constants[left.value > right.value]
	elseif operator == "==" then
		return object.constants[left.value == right.value]
	elseif operator == "!=" then
		return object.constants[left.value ~= right.value]
	end

	return {
		obj_type = object.kinds.ERROR,
		value = `unknown operator: {left.obj_type} {operator} {right.obj_type}`,
	}
end

function eval_infix_expression(
	left: object.BaseObject<unknown>,
	operator: string,
	right: object.BaseObject<unknown>
): object.BaseObject<unknown>
	if left.obj_type == object.kinds.NUMBER and right.obj_type == object.kinds.NUMBER then
		return eval_number_infix_expression(left :: any, operator, right :: any)
	end

	if left.obj_type ~= right.obj_type then
		return {
			obj_type = object.kinds.ERROR,
			value = `type mismatch: {left.obj_type} {operator} {right.obj_type}`,
		}
	end

	if left.obj_type == object.kinds.STRING then
		return eval_string_infix_expression(left :: any, operator, right :: any)
	end

	if operator == "==" then
		return object.constants[left.value == right.value]
	elseif operator == "!=" then
		return object.constants[left.value ~= right.value]
	end

	return {
		obj_type = object.kinds.ERROR,
		value = `unknown operator: {left.obj_type} {operator} {right.obj_type}`,
	}
end

function eval_if_expression(node: AST.IfExpression, env: object.Environment)
	local condition = eval(node.condition, env)
	if condition.obj_type == object.kinds.ERROR then
		return condition
	end

	if condition ~= object.constants[false] and condition ~= object.constants.null then -- Truthy
		return eval(node.consequence, env)
	elseif node.alternative then
		return eval(node.alternative, env)
	end

	return object.constants.null
end

function eval_block_statement(node: AST.BlockStatement, env: object.Environment)
	local result = nil

	for _, statement in ipairs(node.statements) do
		result = eval(statement, env)

		if result and (result.obj_type == object.kinds.RETURN or result.obj_type == object.kinds.ERROR) then
			return result
		end
	end

	return result
end

function eval_expressions(list: { AST.Expression }, env: object.Environment): { object.BaseObject<unknown> }
	local result = {}

	for _, expr in ipairs(list) do
		local evaluated = eval(expr, env)

		if evaluated.obj_type == object.kinds.ERROR then
			return { evaluated }
		end

		table.insert(result, evaluated)
	end

	return result
end

function eval_identifier(node: AST.Identifier, env: object.Environment): object.BaseObject<unknown>
	local value, ok = env:get(node.value)
	if ok then
		if value.const then
			return {
				obj_type = object.kinds.ERROR,
				value = "cannot modify constant",
			} :: object.BaseObject<string>
		end

		return value.value
	end

	return builtin[node.value]
		or {
			obj_type = object.kinds.ERROR,
			value = `identifier not found: {node.value}`,
		} :: object.BaseObject<string>
end

function eval_program(program: AST.Program, env: object.Environment)
	local result = nil

	for _, stmt in ipairs(program.statements) do
		result = eval(stmt, env)

		if result and result.obj_type == object.kinds.RETURN then
			return result.value
		elseif result and result.obj_type == object.kinds.ERROR then
			return result
		end
	end

	return result
end

function eval(node: AST.Node, env: object.Environment): object.BaseObject<unknown> | any
	if node.node_type == AST.PROGRAM then -- Statements
		return eval_program(node :: AST.Program, env)
	elseif node.node_type == AST.EXPRESSION_STATEMENT then
		return eval((node :: AST.ExpressionStatement).expression, env)
	elseif node.node_type == AST.BLOCK_STATEMENT then
		return eval_block_statement(node :: AST.BlockStatement, env)
	elseif node.node_type == AST.RETURN_STATEMENT then
		local value = eval((node :: AST.ReturnStatement).return_value, env)
		if value.obj_type == object.kinds.ERROR then
			return value
		end

		return {
			obj_type = object.kinds.RETURN,
			value = value,
		} :: object.BaseObject<unknown>
	elseif node.node_type == AST.LET_STATEMENT then
		local value = eval((node :: AST.LetStatement).value, env)
		if value.obj_type == object.kinds.ERROR then
			return value
		end

		if builtin[(node :: AST.LetStatement).name.value] then
			return {
				obj_type = object.kinds.ERROR,
				value = "cannot modify constant",
			} :: object.BaseObject<string>
		end

		local got, ok = env:get((node :: AST.LetStatement).name.value)
		if ok and got.const then
			return {
				obj_type = object.kinds.ERROR,
				value = "cannot modify constant",
			} :: object.BaseObject<string>
		end

		env:set((node :: AST.LetStatement).name.value, value, (node :: AST.LetStatement).constant)
	elseif node.node_type == AST.ASSIGNMENT_STATEMENT then
		local ident = eval_identifier((node :: AST.AssignmentStatement).name, env)
		if ident.obj_type == object.kinds.ERROR then
			return ident
		end

		local value = eval((node :: AST.AssignmentStatement).value, env)
		if value.obj_type == object.kinds.ERROR then
			return value
		end

		if builtin[(node :: AST.AssignmentStatement).name.value] then
			return {
				obj_type = object.kinds.ERROR,
				value = "cannot modify constant",
			} :: object.BaseObject<string>
		end

		local got = env:get((node :: AST.AssignmentStatement).name.value)
		if got.const then
			return {
				obj_type = object.kinds.ERROR,
				value = "cannot modify constant",
			} :: object.BaseObject<string>
		end

		env:set((node :: AST.AssignmentStatement).name.value, value, false)
	elseif node.node_type == AST.ARRAY_INDEX_ASSIGNMENT_STATEMENT then
		local array = eval((node :: AST.ArrayIndexAssignmentStatement).array, env)
		if array.obj_type == object.kinds.ERROR then
			return array
		end

		local index = eval((node :: AST.ArrayIndexAssignmentStatement).index, env)
		if index.obj_type == object.kinds.ERROR then
			return index
		end

		local value = eval((node :: AST.ArrayIndexAssignmentStatement).value, env)
		if value.obj_type == object.kinds.ERROR then
			return value
		end

		if array.obj_type == object.kinds.ARRAY and index.obj_type == object.kinds.NUMBER then
			local arr = array.value :: { object.BaseObject<unknown> }
			local ind = index.value :: number

			arr[ind + 1] = value
			return nil :: any
		end

		return {
			obj_type = object.kinds.ERROR,
			value = `index operator not supported: {array.obj_type}`
		}
	elseif node.node_type == AST.IDENTIFIER then
		return eval_identifier(node :: AST.Identifier, env)
	elseif node.node_type == AST.STRING_LITERAL then -- Literals
		return {
			obj_type = object.kinds.STRING,
			value = (node :: AST.StringLiteral).value,
		} :: object.BaseObject<string>
	elseif node.node_type == AST.INTEGER_LITERAL then
		return {
			obj_type = object.kinds.NUMBER,
			value = (node :: AST.IntegerLiteral).value,
		} :: object.BaseObject<number>
	elseif node.node_type == AST.BOOLEAN_LITERAL then
		return object.constants[(node :: AST.BooleanLiteral).value]
	elseif node.node_type == AST.FUNCTION_LITERAL then
		return {
			obj_type = object.kinds.FUNCTION,

			body = (node :: AST.FunctionLiteral).body,
			params = (node :: AST.FunctionLiteral).parameters,
			env = env,
		}
	elseif node.node_type == AST.ARRAY_LITERAL then
		local elements = eval_expressions((node :: AST.ArrayLiteral).elements, env)

		return {
			obj_type = object.kinds.ARRAY,
			value = elements,
		} :: object.BaseObject<{ object.BaseObject<unknown> }>
	elseif node.node_type == AST.PREFIX_EXPRESSION then -- Expressions
		local right = eval((node :: AST.PrefixExpression).right, env)
		if right.obj_type == object.kinds.ERROR then
			return right
		end

		return eval_prefix_expression(right, (node :: AST.PrefixExpression).operator)
	elseif node.node_type == AST.INFIX_EXPRESSION then
		local left = eval((node :: AST.InfixExpression).left, env)
		if left.obj_type == object.kinds.ERROR then
			return left
		end

		local right = eval((node :: AST.InfixExpression).right, env)
		if right.obj_type == object.kinds.ERROR then
			return right
		end

		return eval_infix_expression(left, (node :: AST.InfixExpression).operator, right)
	elseif node.node_type == AST.INDEX_EXPRESSION then
		local left = eval((node :: AST.IndexExpression).left, env)
		if left.obj_type == object.kinds.ERROR then
			return left
		end

		local index = eval((node :: AST.IndexExpression).index, env)
		if index.obj_type == object.kinds.ERROR then
			return index
		end

		if left.obj_type == object.kinds.ARRAY and index.obj_type == object.kinds.NUMBER then
			local arr = left.value :: {object.BaseObject<unknown>}
			local ind = index.value :: number

			return arr[ind + 1] or object.constants.null
		end

		return {
			obj_type = object.kinds.ERROR,
			value = `index operator not supported: {left.obj_type}`
		}
	elseif node.node_type == AST.IF_EXPRESSION then
		return eval_if_expression(node :: AST.IfExpression, env)
	elseif node.node_type == AST.CALL_EXPRESSION then
		local fun = (eval((node :: AST.CallExpression).func, env) :: any) :: object.Function
		if fun.obj_type == object.kinds.ERROR then
			return fun :: any
		end

		local args = eval_expressions((node :: AST.CallExpression).arguments, env)
		if #args == 1 and args[1].obj_type == object.kinds.ERROR then
			return args[1]
		end

		if fun.obj_type ~= object.kinds.FUNCTION and fun.obj_type ~= object.kinds.BUILTIN_FUNCTION then
			return {
				obj_type = object.kinds.ERROR,
				value = `not a function: {fun.obj_type}`
			}
		end

		if fun.obj_type == object.kinds.BUILTIN_FUNCTION then
			return ((fun :: any) :: object.BaseObject<(...any) -> any>).value(args)
		end

		local extended_env = object.Environment.new(fun.env)
		for index, param in ipairs(fun.params) do
			extended_env:set(param.value, args[index], false)
		end

		local evaluated = eval(fun.body, extended_env)

		if evaluated.obj_type == object.kinds.RETURN then
			return evaluated.value
		end
		
		return evaluated
	end

	return nil
end

return eval