--!strict
-- Formats a program into a string
local AST = require("../components/ast")
local object = require("../components/evaluator/object")

local stdio = require("@lune/stdio")

type BufferFormattingConfig = {
	offset: number?,
	size: number?,

	ascii: boolean?,
	color: boolean?
}

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
	elseif stmt.node_type == AST.BLOCK_STATEMENT or stmt.node_type == AST.PROGRAM then
		local out = {}

		for _, inner in ipairs((stmt :: AST.BlockStatement).statements) do
			table.insert(out, statementToString(inner))
		end

		return table.concat(out)
	end

	return `UNKNOWN`
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

	return `UNKNOWN`
end

local function format_buffer(b: buffer, config: BufferFormattingConfig)
	local length = buffer.len(b) -- Assuming buffer is a userdata with len method
	local ascii = config.ascii == nil and true or config.ascii
	local offset = config.offset or 0
	local size = config.size or (length - offset)
	local can_color = config.color == nil and true or config.color

	local function color(str: string | number, color: stdio.Color): string
		if not can_color then return str :: any end
		return stdio.color(color) .. str .. stdio.color("reset")
	end

	local function style(str: string | number, style: stdio.Style): string
		if not can_color then
			return str :: any
		end
		return stdio.style(style) .. str .. stdio.style("reset")
	end

	if size < 0 or offset + size > length then
		error(string.format("Size out of bounds! max: %d, got: %d", length, size))
	end

	local final = {
		`Address    {color("00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F", "blue")}{ascii and "  ASCII" or ""}`,
	}

	for line_start = 0, size - 1, 16 do
		-- local line_end = math.min(line_start + 15, size - 1)
		local hex_part = {}
		local ascii_part = {}

		for i = 0, 15 do
			local pos = line_start + i
			if pos < size then
				local byte = buffer.readu8(b, offset + pos)
				hex_part[i + 1] = style(string.format("%02X", byte), if byte == 0 then "dim" else "reset")
				-- Handle ASCII part
				if ascii then
					if byte >= 0x20 and byte <= 0x7E then
						ascii_part[i + 1] = string.char(byte)
					else
						ascii_part[i + 1] = style('.', "dim")
					end
				end
			else
				hex_part[i + 1] = "  " -- Pad missing bytes with spaces
				if ascii then
					ascii_part[i + 1] = " "
				end
			end
		end

		-- Split hex into two groups of 8 bytes
		local first_half = table.concat(hex_part, " ", 1, 8)
		local second_half = table.concat(hex_part, " ", 9, 16)
		local hex_line = first_half .. "  " .. second_half

		-- Format the address for this line
		local address = offset + line_start
		local address_str = color(string.format("%08X:", address), "blue")

		-- Build the line
		local line
		if ascii then
			local ascii_str = table.concat(ascii_part)
			line = string.format("%s  %s  %s", address_str, hex_line, ascii_str)
		else
			line = string.format("%s  %s", address_str, hex_line)
		end

		table.insert(final, line)
	end

	return table.concat(final, "\n")
end

local function format(what: any, config: BufferFormattingConfig?): string
	local typ = typeof(what)
	if typ == "buffer" then
		return format_buffer(what, config or {})
	end

	if (what :: any).node_type then 
    local a = statementToString(what :: any)
    if a ~= "UNKNOWN" then return a end

    return expressionToString(what :: any)
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
				table.insert(out, format(v))
			end

			return `[{table.concat(out, ", ")}]`
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
