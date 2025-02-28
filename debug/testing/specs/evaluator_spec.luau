local object = require("../../../components/evaluator/object")
local parse = require("../../../components/parser")
local lex = require("../../../components/lexer")

local eval = require("../../../components/evaluator/evaluator")

local assert, it = require("../globals")
local format = require("../../format")

local OBJ_TYPES_STRINGS = table.freeze({
	[object.kinds.STRING] = "STRING",
	[object.kinds.NUMBER] = "NUMBER",
	[object.kinds.BOOLEAN] = "BOOLEAN",
	[object.kinds.ERROR] = "ERROR",
	[object.kinds.FUNCTION] = "FUNCTION",
	[object.kinds.ARRAY] = "ARRAY",
	[object.kinds.RETURN] = "RETURN",
	[object.kinds.NULL] = "NULL",
	[object.kinds.BUILTIN_FUNCTION] = "BUILTIN_FUNCTION",
	[object.kinds.HASH] = "HASH",
})

function dictionary_len(dict): number
	local len = 0

	for _ in pairs(dict) do
		len += 1
	end

	return len
end

local function expr_typeof(expr: object.BaseObject<unknown> | any): string
	local typ = type(expr)

	if typ == "table" then
		if type(expr.obj_type) == "number" then
			return OBJ_TYPES_STRINGS[expr.obj_type]
		end

		return expr.obj_type
	end

	if typ == "number" then
		return OBJ_TYPES_STRINGS[expr] or typ
	end

	return typ
end

local function expect(what, expr, err_lvl)
	assert.are_equal(
		expr_typeof(what),
		expr_typeof(expr),
		`Expected expression to be an {expr_typeof(what)}, got {expr_typeof(expr)}`,
		err_lvl
	)
end

local function test_eval(input)
	local program = parse(lex(input))
	return eval(program, object.Environment.new())
end

local function test_object(obj: object.BaseObject<unknown>, expected_type: string, expected_value: any)
	expect(expected_type, obj, 4)

	assert.are_equal(obj.value, expected_value, `Expected object.value to be {expected_value}, got {obj.value}`, 3)
	return true
end

return {
	describe = "the evaluator",
	tests = {
		it("can do integer expressions", function()
			local tests = {
				{ "5", 5 },
				{ "10", 10 },
				{ "-5", -5 },
				{ "-10", -10 },
				{ "5 + 5 + 5 + 5 - 10", 10 },
				{ "2 * 2 * 2 * 2 * 2", 32 },
				{ "-50 + 100 + -50", 0 },
				{ "5 * 2 + 10", 20 },
				{ "5 + 2 * 10", 25 },
				{ "20 + 2 * -10", 0 },
				{ "50 / 2 * 2 + 10", 60 },
				{ "2 * (5 + 10)", 30 },
				{ "3 * 3 * 3 + 10", 37 },
				{ "3 * (3 * 3) + 10", 37 },
				{ "(5 + 10 * 2 + 15 / 3) * 2 + -10", 50 },
			}

			for _, test in ipairs(tests) do
				local result = test_eval(test[1])

				test_object(result, object.kinds.NUMBER, test[2])
			end
		end),

		it("can do boolean expressions", function()
			local tests = {
				{ "true", true },
				{ "false", false },
				{ "1 < 2", true },
				{ "1 > 2", false },
				{ "1 < 1", false },
				{ "1 > 1", false },
				{ "1 == 1", true },
				{ "1 != 1", false },
				{ "1 == 2", false },
				{ "1 != 2", true },
				{ "true == true", true },
				{ "false == false", true },
				{ "true == false", false },
				{ "true != false", true },
				{ "false != true", true },
				{ "(1 < 2) == true", true },
				{ "(1 < 2) == false", false },
				{ "(1 > 2) == true", false },
				{ "(1 > 2) == false", true },
				{ '"Hello, world!" == "Hello" + ", " + "world!"', true },
			}

			for _, test in ipairs(tests) do
				local result = test_eval(test[1])

				test_object(result, object.kinds.BOOLEAN, test[2])
			end
		end),

		it("can do bang expressions", function()
			local tests = {
				{ "!true", false },
				{ "!false", true },
				{ "!5", false },
				{ "!!true", true },
				{ "!!false", false },
				{ "!!5", true },
			}

			for _, test in ipairs(tests) do
				local result = test_eval(test[1])
				test_object(result, object.kinds.BOOLEAN, test[2])
			end
		end),

		it("can do if expressions", function()
			local tests = {
				{ "if (true) { 10 }", 10 },
				{ "if (false) { 10 }", nil },
				{ "if (1) { 10 }", 10 },
				{ "if (1 < 2) { 10 }", 10 },
				{ "if (1 > 2) { 10 }", nil },
				{ "if (1 > 2) { 10 } else { 20 }", 20 },
				{ "if (1 < 2) { 10 } else { 20 }", 10 },
			}

			for _, test in ipairs(tests) do
				local result = test_eval(test[1])

				if test[2] then
					test_object(result, object.kinds.NUMBER, test[2])
				else
					test_object(result, object.kinds.NULL, "NULL")
				end
			end
		end),

		it("can do returns", function()
			local tests = {
				{ "return 10;", 10 },
				{ "return 10; 9;", 10 },
				{ "return 2 * 5; 9;", 10 },
				{ "9; return 2 * 5; 9;", 10 },
				{
					[[
                if (10 > 1) {
                  if (10 > 1) {
                    return 10;
                  }

                  return 1;
                }
            ]],
					10,
				},
			}

			for _, test in ipairs(tests) do
				local evaluated = test_eval(test[1])

				test_object(evaluated, object.kinds.NUMBER, test[2])
			end
		end),

		it("can produce errors", function()
			local tests = {
				{ "5 + true;", "type mismatch: 1 + 2" },
				{ "5 + true; 5;", "type mismatch: 1 + 2" },
				{ "-true", "unknown operator: -2" },
				{ "true + false;", "unknown operator: 2 + 2" },
				{ "5; true + false; 5", "unknown operator: 2 + 2" },
				{ "if (10 > 1) { true + false; }", "unknown operator: 2 + 2" },
				{
					[[
                if (10 > 1) {
                  if (10 > 1) {
                    return true + false;
                  }
                  return 1;
                }
            ]],
					"unknown operator: 2 + 2",
				},
				{ "foobar", "identifier not found: foobar" },
				{ '"Hello" - "World"', "unknown operator: 0 - 0" },
			}

			for _, test in ipairs(tests) do
				local evaluated = test_eval(test[1])

				expect(object.kinds.ERROR, evaluated)
				---@cast evaluated Error

				assert.are_equal(
					test[2],
					evaluated.value,
					string.format("Expected error message: '%s', got '%s'", test[2], evaluated.value)
				)
			end
		end),

		it("can do let statements", function()
			local tests = {
				{ "let a = 5; a;", 5 },
				{ "let a = 5 * 5; a;", 25 },
				{ "let a = 5; let b = a; b;", 5 },
				{ "let a = 5; let b = a; let c = a + b + 5; c;", 15 },
			}

			for _, test in ipairs(tests) do
				test_object(test_eval(test[1]), object.kinds.NUMBER, test[2])
			end
		end),

		it("can do functions", function()
			local input = { "fn(x) { x + 2; };", "(x + 2)" }

			local evaluated = test_eval(input[1]) :: object.Function
			expect(object.kinds.FUNCTION, evaluated, 3)

			---@cast evaluated Function
			assert.are_equal(
				1,
				#evaluated.params,
				string.format("Expected 1 function parameter, got %s!", tostring(#evaluated.params))
			)

			assert.are_equal(
				"x",
				evaluated.params[1].value,
				string.format("Expected parameter to be %s, got %s", "x", evaluated.params[1].value)
			)

			assert.are_equal(
				"(x + 2)",
				format(evaluated.body),
				string.format("Expected body to be (x + 2), got %s", format(evaluated.body))
			)
		end),

		it("can do actual functions", function()
			local tests = {
				{ "let identity = fn(x) { x; }; identity(5);", 5 },
				{ "let identity = fn(x) { return x; }; identity(5);", 5 },
				{ "let double = fn(x) { x * 2; }; double(5);", 10 },
				{ "let add = fn(x, y) { x + y; }; add(5, 5);", 10 },
				{ "let add = fn(x, y) { x + y; }; add(5 + 5, add(5, 5));", 20 },
				{ "fn(x) { x; }(5)", 5 },
			}

			for _, test in ipairs(tests) do
				test_object(test_eval(test[1]), object.kinds.NUMBER, test[2])
			end
		end),

		it("can do strings", function()
			local input = '"Hello, world!"'

			local evaluated = test_eval(input)
			expect(object.kinds.STRING, evaluated)

			---@cast evaluated String
			assert.are_equal(
				"Hello, world!",
				evaluated.value,
				string.format("String expected %s, got %s", input, evaluated.value)
			)
		end),

		it("can concatenate strings", function()
			local input = '"Hello" + ", " + "world!"'

			local evaluated = test_eval(input)
			expect(object.kinds.STRING, evaluated)

			---@cast evaluated String
			assert.are_equal(
				"Hello, world!",
				evaluated.value,
				string.format("String expected %s, got %s", '"Hello, world!"', evaluated.value)
			)
		end),

		-- Once hash maps get implemented, I want to add them builtins into those, rather than global
		it("can call builtin functions", function()
			local tests = {
				{ 'len("")', 0 },
				{ 'len("four")', 4 },
				{ 'len("hello world")', 11 },
				{ "len(1)", "expected 0, got 1" },
				{ 'len("one", "two")', "expected 1 argument, got 2" },
			}

			for _, test in ipairs(tests) do
				local evaluated = test_eval(test[1])

				if evaluated.obj_type == object.kinds.NUMBER then
					test_object(evaluated, object.kinds.NUMBER, test[2])
				else
					expect(object.kinds.ERROR, evaluated)
					---@cast evaluated Error

					assert.are_equal(
						test[2],
						evaluated.value,
						string.format("Expected error '%s', got '%s'", test[2], evaluated.value)
					)
				end
			end
		end),

		it("can evaluate array indexing", function()
			local input = "[1, 2 * 2, 3 + 3]"

			local evaluated = test_eval(input) :: object.Array
			expect(object.kinds.ARRAY, evaluated)

			assert.are_equal(3, #evaluated.value, `Expected 3 elements, got {#evaluated.value}`)

			test_object(evaluated.value[1], object.kinds.NUMBER, 1)
			test_object(evaluated.value[2], object.kinds.NUMBER, 4)
			test_object(evaluated.value[3], object.kinds.NUMBER, 6)
		end),

		it("can really index arrays", function()
			local tests = {
				{ "[1, 2, 3][0]", 1 },
				{ "[1, 2, 3][1]", 2 },
				{ "[1, 2, 3][2]", 3 },
				{ "let i = 0; [1][i];", 1 },
				{ "[1, 2, 3][1 + 1];", 3 },
				{ "let myArray = [1, 2, 3]; myArray[2];", 3 },
				{ "let myArray = [1, 2, 3]; myArray[0] + myArray[1] + myArray[2];", 6 },
				{ "let myArray = [1, 2, 3]; let i = myArray[0]; myArray[i]", 2 },
				{ "[1, 2, 3][3]", nil },
				{ "[1, 2, 3][-1]", nil },
			}

			for _, test in ipairs(tests) do
				local evaluated = test_eval(test[1])

				if test[2] then
					test_object(evaluated, object.kinds.NUMBER, test[2])
				else
					test_object(evaluated, object.kinds.NULL, "NULL")
				end
			end
		end),

		it("can evaluate has literals", function()
			local input = [[let two = "two";
{
"one": 10 - 9,
two: 1 + 1,
"thr" + "ee": 6 / 2,
4: 4,
true: 5,
false: 6
}]]

			local evaluated = test_eval(input) :: object.Hash
			expect(object.kinds.HASH, evaluated)

			local expected = {
				["one"] = 1,
				["two"] = 2,
				["three"] = 3,
				[4] = 4,
				[true] = 5,
				[false] = 6,
			}

			assert.are_equal(dictionary_len(evaluated.value), 6, `Expected 6 pairs, got $1`)
			for exp_key, exp_value in pairs(expected) do
				local pair = evaluated.value[exp_key]

				test_object(pair, object.kinds.NUMBER, exp_value)
			end
		end),

		it("can evaluate has literals", function()
			local tests = {
        {'{"foo": 5}["foo"]', 5},
        {'{"foo": 4}["bar"]', nil},
        {'let key = "foo"; {"foo": 5}[key]`', 5},
        {'{}["foo"]', nil},
        {'{5: 5}[5]', 5},
        {'{true: 5}[true]', 5},
        {'{false: 5}[false]', 5}
      }

			for _, test in pairs(tests) do
        local evaluated = test_eval(test[1]) :: object.Hash

        if test[2] == nil then
          test_object(evaluated, object.kinds.NULL, "NULL")
        else
          test_object(evaluated, object.kinds.NUMBER, test[2])        
        end
			end
		end),
	},
}
