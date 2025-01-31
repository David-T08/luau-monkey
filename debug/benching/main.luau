local input = [[
    let five = 5;
    let ten = 10;
    let add = fn(x, y) {
        return x + y;
    };
    let result = add(five, ten);
    
    !-/*5;
    5 < 10 > 5;
    
    if (5 < 10) {
        return true;
    } else {
        return false;
    }
    
    10 == 10;
    10 != 9;
    "foobar";
    "foo bar baz";
    "string with \"escaped quotes\" inside";
    "multiple\\backslashes";
    
    [1, 2, 3, "test", true, false];
    {"key": "value", "nested": {"inner": 42}};
    {1: 2, 3: [4, 5], 6: {7: 8}};
    
    let const x = 5;
    let mut y = "changeable";
    y = "new value";
    
    while (x < 100) {
        x = x + 1;
    }
    
    for (let i = 0; i < 10; i = i + 1) {
        puts(i);
    }
    
    "Long multiline string with various edge cases"
    "Another one with \"nested quotes\" and a newline\nnext line";
    
    let complex = fn(a, b, c) {
        if (a > b && b < c || c == a) {
            return "complex condition met";
        } else {
            return "no match";
        }
    };
    
    complex(1, 2, 3);
    
    // Large numbers and edge cases
    1234567890;
    0xDEADBEEF;
    0b101010;
    3.1415926535;
    -42;
]]

local bench = require("bencher")
local lexer = require("../../components/lexer")

bench("lexer", lexer, 1e4, input)