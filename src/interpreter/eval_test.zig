const std = @import("std");

const Lexer = @import("lexer/lexer.zig").Lexer;
const ast = @import("ast/ast.zig");
const Parser = @import("parser/parser.zig").Parser;
const Object = @import("intern/object.zig");
const Evaluator = @import("eval/evaluator.zig").Evaluator;
const Environment = @import("intern/environment.zig").Environment;

const stderr = std.io.getStdOut().writer();

test "Test Integer literal evaluation" {
    const expected = [_]struct { []const u8, i64 }{
        .{ "5;", 5 },
        .{ "0;", 0 },
        .{ "10;", 10 },
        .{ "100;", 100 },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_integer_object(evaluated, exp[1]);
    }
}

test "Test Boolean literal evaluation" {
    const expected = [_]struct { []const u8, bool }{
        .{ "true;", true },
        .{ "false;", false },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_boolean_object(evaluated, exp[1]);
    }
}

test "Test String literal evaluation" {
    const expected = [_]struct { []const u8, []const u8 }{
        .{ "\"hello\";", "hello" },
        .{ "\"hello, world!\";", "hello, world!" },
        .{ "\"foo-bar?!@\";", "foo-bar?!@" },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_string_object(evaluated, exp[1]);
    }
}

test "Test String concatenation" {
    const expected = [_]struct { []const u8, []const u8 }{
        .{
            \\"hello" + ", " + "world!";
            ,
            "hello, world!",
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_string_object(evaluated, exp[1]);
    }
}

test "Test Array literal evaluation" {
    const expected = [_]struct { []const u8, u8, [3]u8 }{
        .{ "[1, 2 * 2, 3 + 3];", 3, [_]u8{ 1, 4, 6 } },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try std.testing.expectEqualStrings(evaluated.typename(), "Array");

        const elements = evaluated.array.elements.items;
        try std.testing.expectEqual(elements.len, exp[1]);

        for (elements, 0..) |elem, i| {
            try test_integer_object(elem, exp[2][i]);
        }
    }
}

test "Test Hash evaluation" {
    const Result = union(enum) {
        int: i64,
        bool: bool,
        string: []const u8,
    };
    const expected = comptime [_]struct { []const u8, [2][]const u8, [2]Result }{
        .{
            \\{"name": "John", "workAt": "fsociety"};
            ,
            [2][]const u8{ "name", "workAt" },
            [2]Result{ Result{ .string = "John" }, Result{ .string = "fsociety" } },
        },
        .{
            \\{"age": 100 - 1, "zip_code": 78 * 10 + 6};
            ,
            [2][]const u8{ "age", "zip_code" },
            [2]Result{ Result{ .int = 99 }, Result{ .int = 786 } },
        },
        .{
            \\{"real": !!true, "false": !true};
            ,
            [2][]const u8{ "real", "false" },
            [2]Result{ Result{ .bool = true }, Result{ .bool = false } },
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try std.testing.expectEqualStrings(evaluated.typename(), "Hash");

        var pairs = evaluated.hash.pairs.iterator();
        var i: usize = 0;

        while (pairs.next()) |pair| : (i += 1) {
            const key = pair.key_ptr.*;
            const value = pair.value_ptr.*;

            const exp_key = exp[1][i];
            try std.testing.expectEqualStrings(exp_key, key);

            const exp_value = exp[2][i];
            switch (exp_value) {
                .int => |int| {
                    try test_integer_object(value, int);
                },
                .string => |str| {
                    try test_string_object(value, str);
                },
                .bool => |bool_| {
                    try test_boolean_object(value, bool_);
                },
            }
        }
    }
}

test "Test Array indexing evaluation" {
    const Result = union(enum) {
        int: i64,
        err: []const u8,
    };
    const expected = comptime [_]struct { []const u8, Result }{
        .{ "[1, 2 * 2, 3 + 3][0];", Result{ .int = 1 } },
        .{ "[1, 2, 3 + 3][1];", Result{ .int = 2 } },
        .{ "[1, 4, 999][2];", Result{ .int = 999 } },
        .{ "var i = 0; [1][i];", Result{ .int = 1 } },
        .{ "[1, 2, 3][1 + 1];", Result{ .int = 3 } },
        .{ "var myArray = [1, 2, 3]; myArray[2];", Result{ .int = 3 } },
        .{ "var myArray = [1, 2, 3]; myArray[0] + myArray[1] + myArray[2];", Result{ .int = 6 } },
        .{ "var myArray = [1, 2, 3]; var i = myArray[0]; myArray[i];", Result{ .int = 2 } },
        .{ "[1, 2, 3][3];", Result{ .err = "Index 3 out of range. Maximum is 2." } },
        .{ "[1, 2, 3][-1];", Result{ .err = "Index -1 is invalid, must be positive." } },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        switch (exp[1]) {
            .int => |int| {
                try std.testing.expectEqualStrings(evaluated.typename(), "Integer");
                try test_integer_object(evaluated, int);
            },
            .err => |err| {
                // try std.testing.expectEqualStrings(evaluated.typename(), "Null");
                try test_error_object(evaluated, err);
            },
        }
    }
}

test "Test Hash indexing evaluation" {
    const Result = union(enum) {
        int: i64,
        err: []const u8,
    };
    const expected = comptime [_]struct { []const u8, Result }{
        .{
            \\{"foo": 5}["foo"]
            ,
            Result{ .int = 5 },
        },
        .{
            \\{"foo": 5}["bar"];
            ,
            Result{ .err = "Key 'bar' doesn't exists." },
        },
        .{
            \\{"foo": 5}[5];
            ,
            Result{ .err = "Index on string hashmap must be an String, found: Integer" },
        },
        .{
            \\var key = "foo"; {"foo": 5*6}[key];
            ,
            Result{ .int = 30 },
        },
        .{
            \\{}["foo"];
            ,
            Result{ .err = "Key 'foo' doesn't exists on empty string hashmap." },
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        switch (exp[1]) {
            .int => |int| {
                try std.testing.expectEqualStrings(evaluated.typename(), "Integer");
                try test_integer_object(evaluated, int);
            },
            .err => |err| {
                // try std.testing.expectEqualStrings(evaluated.typename(), "Null");
                try test_error_object(evaluated, err);
            },
        }
    }
}

test "Test len Builtin function" {
    const Result = union(enum) {
        res: i64,
        err: []const u8,
    };
    const expected = comptime [_]struct { []const u8, Result }{
        .{
            \\len("hello");
            ,
            Result{ .res = 5 },
        },
        .{
            \\len("hello, world!");
            ,
            Result{ .res = 13 },
        },
        .{
            \\len("This house has people in it...");
            ,
            Result{ .res = 30 },
        },
        .{
            "len(1);",
            Result{ .err = "argument to `len` not supported, got Integer" },
        },
        .{
            \\len("one", "two");
            ,
            Result{ .err = "wrong number of arguments. got=2, want=1" },
        },
        .{
            \\len(["one", "two"]);
            ,
            Result{ .res = 2 },
        },
        .{
            \\len(["one", "two", 5, 6]);
            ,
            Result{ .res = 4 },
        },
        .{
            \\len([2*2, 4+3, 100/2]);
            ,
            Result{ .res = 3 },
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        switch (exp[1]) {
            .res => |int_res| {
                try test_integer_object(evaluated, int_res);
            },
            .err => |msg| {
                const returned_err_msg = evaluated.err.msg;
                try std.testing.expectEqualStrings(msg, returned_err_msg);
            },
        }
    }
}

test "Test head Builtin function" {
    const Result = union(enum) {
        int_res: i64,
        str_res: []const u8,
        err: []const u8,
    };
    const expected = comptime [_]struct { []const u8, Result }{
        .{
            \\head(["hello"]);
            ,
            Result{ .str_res = "hello" },
        },
        .{
            \\head([1, 4, 8]);
            ,
            Result{ .int_res = 1 },
        },
        .{
            \\head([]);
            ,
            Result{ .err = "`head` is not applicable on empty array." },
        },
        .{
            \\head("This house has people in it...");
            ,
            Result{ .err = "argument to `head` not supported, got String" },
        },
        .{
            "head(1);",
            Result{ .err = "argument to `head` not supported, got Integer" },
        },
        .{
            \\head(["one", "two"], [1]);
            ,
            Result{ .err = "wrong number of arguments. got=2, want=1" },
        },
        .{
            \\head([2*2, 4+3, 100/2]);
            ,
            Result{ .int_res = 4 },
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        switch (exp[1]) {
            .int_res => |int_res| {
                try test_integer_object(evaluated, int_res);
            },
            .str_res => |str_res| {
                try test_string_object(evaluated, str_res);
            },
            .err => |msg| {
                const returned_err_msg = evaluated.err.msg;
                try std.testing.expectEqualStrings(msg, returned_err_msg);
            },
        }
    }
}

test "Test last Builtin function" {
    const Result = union(enum) {
        int_res: i64,
        str_res: []const u8,
        err: []const u8,
    };
    const expected = comptime [_]struct { []const u8, Result }{
        .{
            \\last(["hello"]);
            ,
            Result{ .str_res = "hello" },
        },
        .{
            \\last([1, 4, 8]);
            ,
            Result{ .int_res = 8 },
        },
        .{
            \\last([]);
            ,
            Result{ .err = "`last` is not applicable on empty array." },
        },
        .{
            \\last("This house has people in it...");
            ,
            Result{ .err = "argument to `last` not supported, got String" },
        },
        .{
            "last(1);",
            Result{ .err = "argument to `last` not supported, got Integer" },
        },
        .{
            \\last(["one", "two"], [1]);
            ,
            Result{ .err = "wrong number of arguments. got=2, want=1" },
        },
        .{
            \\last([2*2, 4+3, 100/2]);
            ,
            Result{ .int_res = 50 },
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        switch (exp[1]) {
            .int_res => |int_res| {
                try test_integer_object(evaluated, int_res);
            },
            .str_res => |str_res| {
                try test_string_object(evaluated, str_res);
            },
            .err => |msg| {
                const returned_err_msg = evaluated.err.msg;
                try std.testing.expectEqualStrings(msg, returned_err_msg);
            },
        }
    }
}

test "Test tail Builtin function" {
    const Result = union(enum) {
        int_res: i64,
        err: []const u8,
    };
    // TOFIX: A little bit cheating by test with len...
    const expected = comptime [_]struct { []const u8, Result }{
        .{
            \\var tail = tail(["hello"]);
            \\len(tail);
            ,
            Result{ .int_res = 0 },
        },
        .{
            \\var tail = tail([1, 4, 8]);
            \\len(tail);
            ,
            Result{ .int_res = 2 },
        },
        .{
            \\tail([]);
            ,
            Result{ .err = "`tail` is not applicable on empty array." },
        },
        .{
            \\tail("This house has people in it...");
            ,
            Result{ .err = "argument to `tail` not supported, got String" },
        },
        .{
            "tail(1);",
            Result{ .err = "argument to `tail` not supported, got Integer" },
        },
        .{
            \\tail(["one", "two"], [1]);
            ,
            Result{ .err = "wrong number of arguments. got=2, want=1" },
        },
        .{
            \\var tail = tail([2*2, 4+3, 100/2]);
            \\len(tail);
            ,
            Result{ .int_res = 2 },
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        switch (exp[1]) {
            .int_res => |int_res| {
                try test_integer_object(evaluated, int_res);
            },
            .err => |msg| {
                const returned_err_msg = evaluated.err.msg;
                try std.testing.expectEqualStrings(msg, returned_err_msg);
            },
        }
    }
}

test "Test push Builtin functions" {
    const Result = union(enum) {
        res: i64,
        err: []const u8,
    };
    const expected = comptime [_]struct { []const u8, Result }{
        .{
            \\var array = [2*2, 4+3, 100/2];
            \\var clone = push(array, 18);
            \\len(clone);
            ,
            Result{ .res = 4 },
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        switch (exp[1]) {
            .res => |int_res| {
                try test_integer_object(evaluated, int_res);
            },
            .err => |msg| {
                const returned_err_msg = evaluated.err.msg;
                try std.testing.expectEqualStrings(msg, returned_err_msg);
            },
        }
    }
}

test "Test Prefix ! op with boolean" {
    const expected = [_]struct { []const u8, bool }{
        .{ "!true;", false },
        .{ "!false;", true },
        .{ "!!false;", false },
        .{ "!!true;", true },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_boolean_object(evaluated, exp[1]);
    }
}

test "Test expressions with integers" {
    const expected = [_]struct { []const u8, i64 }{
        .{ "5;", 5 },
        .{ "10;", 10 },
        .{ "-10;", -10 },
        .{ "-999;", -999 },
        .{ "5 + 5 + 5 + 5 - 10;", 10 },
        .{ "2 * 2 * 2 * 2 * 2;", 32 },
        .{ "-50 + 100 + -50;", 0 },
        .{ "5 * 2 + 10;", 20 },
        .{ "5 + 2 * 10;", 25 },
        .{ "20 + 2 * -10;", 0 },
        .{ "50 / 2 * 2 + 10;", 60 },
        .{ "2 * (5 + 10);", 30 },
        .{ "3 * 3 * 3 + 10;", 37 },
        .{ "3 * (3 * 3) + 10;", 37 },
        .{ "(5 + 10 * 2 + 15 / 3) * 2 + -10;", 50 },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_integer_object(evaluated, exp[1]);
    }
}

test "Test expressions with booleans" {
    const expected = [_]struct { []const u8, bool }{
        .{ "true;", true },
        .{ "false;", false },
        .{ "1 < 2;", true },
        .{ "1 > 2;", false },
        .{ "1 < 1;", false },
        .{ "1 > 1;", false },
        .{ "1 == 1;", true },
        .{ "1 != 1;", false },
        .{ "1 == 2;", false },
        .{ "1 != 2;", true },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_boolean_object(evaluated, exp[1]);
    }
}

test "Test conditions" {
    const expected = [_]struct { []const u8, ?i64 }{
        .{ "if (true): 10; end", 10 },
        .{ "if (false): 10; end;", null },
        .{ "if (1 < 2): 10; end", 10 },
        .{ "if (1 > 2): 10; end;", null },
        .{ "if (1 > 2): 10; else: 20; end", 20 },
        .{ "if (1 < 2): 10; else: 20; end;", 10 },
    };

    // if (5 * 5 + 10 > 34): 99; else: 100; end;
    // if (5 * 5 + 10 < 34): 99; else: 100; end;
    // if ((1000 / 2) + 250 * 2 == 1000): 9999; end;

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        switch (evaluated.*) {
            .integer => try test_integer_object(evaluated, exp[1].?),
            .null => {},
            else => unreachable,
        }
    }
}

test "Test return statement" {
    const expected = [_]struct { []const u8, i64 }{
        .{ "ret 10;", 10 },
        .{ "ret 10; 9;", 10 },
        .{ "ret 2 * 5; 9;", 10 },
        .{ "9; ret 2 * 5; 9;", 10 },
        .{
            \\if (10 > 1):
            \\  if (10 > 1):
            \\      ret 10;
            \\  end
            \\  ret 1;
            \\end
            ,
            10,
        },
    };

    // if (10 > 1): if (10 > 1): ret 10; end; ret 1;end;

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_integer_object(evaluated, exp[1]);
    }
}

test "Test errors" {
    const expected = [_]struct { []const u8, []const u8 }{
        .{
            "5 + true;",
            "type mismatch: Integer + Boolean",
        },
        .{
            "5 + true; 5;",
            "type mismatch: Integer + Boolean",
        },
        .{
            \\"hello" - "world";
            ,
            "unknown operator: String - String",
        },
        .{
            "-true",
            "unknown operator: -Boolean",
        },
        .{
            "true + false;",
            "unknown operator: Boolean + Boolean",
        },
        .{
            "5; true + false; 5;",
            "unknown operator: Boolean + Boolean",
        },
        .{
            "if (10 > 1): true + false; end",
            "unknown operator: Boolean + Boolean",
        },
        .{
            \\if (10 > 1):
            \\  if (10 > 1):
            \\      ret true + false;
            \\  end
            \\  ret 1;
            \\end
            ,
            "unknown operator: Boolean + Boolean",
        },
        .{
            "foobar",
            "identifier not found: foobar",
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_error_object(evaluated, exp[1]);
    }
}

test "Test bindings" {
    const expected = [_]struct { []const u8, i64 }{
        .{ "var a = 5; a;", 5 },
        .{ "var a = 5 * 5; a;", 25 },
        .{ "var a = 5; var b = a; b;", 5 },
        .{ "var a = 5; var b = a; var c = a + b + 5; c;", 15 },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_integer_object(evaluated, exp[1]);
    }
}

test "Test Literal functions" {
    const expected = [_]struct { []const u8, u8, []const u8, []const u8 }{
        .{ "fn(x): x + 2; end", 1, "x", "(x + 2)" },
        .{ "fn(x, y): x + y; end;", 2, "x, y", "(x + y)" },
        .{ "fn(x, foo, bar): x + foo * bar; end", 3, "x, foo, bar", "(x + (foo * bar))" },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_func_object(evaluated, exp);
    }
}

test "Test Named functions" {
    const expected = [_]struct { []const u8, u8, []const u8, []const u8 }{
        .{ "fn plus_two(x): x + 2; end", 1, "x", "(x + 2)" },
        .{ "fn add(x, y): x + y; end", 2, "x, y", "(x + y)" },
        .{ "fn foobar(x, foo, bar): x + foo * bar; end", 3, "x, foo, bar", "(x + (foo * bar))" },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_func_object(evaluated, exp);
    }
}

test "Test functions call" {
    const expected = [_]struct { []const u8, i64 }{
        .{ "var identity = fn(x): x; end; identity(5);", 5 },
        .{ "fn identity(x): x; end identity(5);", 5 },
        .{ "var identity = fn(x): ret x; end; identity(5);", 5 },
        .{ "var double = fn(x): x * 2; end; double(5);", 10 },
        .{ "fn double(x): x * 2; end double(7);", 14 },
        .{ "var add = fn(x, y): x + y; end; add(5, 5);", 10 },
        .{ "fn add(x, y): x + y; end add(6, 6);", 12 },
        .{ "var add = fn(x, y): ret x + y; end; add(6 + 1, add(4, 3));", 14 },
        .{ "fn add(x, y): ret x + y; end add(5 + 5, add(5, 5));", 20 },
        .{ "fn(x): x; end(6)", 6 },
        .{ "fn(x, y): x * y; end(6, 6)", 36 },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_integer_object(evaluated, exp[1]);
    }
}

test "Test closure" {
    const expected = [_]struct { []const u8, i64 }{
        .{
            \\var newAdder = fn(x):
            \\  ret fn(y): ret x + y; end;
            \\end;
            \\var addTwo = newAdder(2);
            \\addTwo(6);
            ,
            8,
        },
        // .{
        //     \\fn mul_by(x):
        //     \\   ret fn(y): ret x * y; end;
        //     \\end
        //     \\var mul_by_ten = mul_by(10);
        //     \\mul_by_ten(2);
        //     ,
        //     20,
        // },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_integer_object(evaluated, exp[1]);
    }
}

test "Test high order functions" {
    const expected = [_]struct { []const u8, i64 }{
        .{
            \\var add = fn(x, y): ret x+y; end;
            \\var apply = fn(func, a, b): ret func(a,b); end;
            \\apply(add, 7, 3);
            ,
            10,
        },
        .{
            \\var sub = fn(x, y): x-y; end;
            \\var apply = fn(func, a, b): ret func(a,b); end;
            \\apply(sub, 7, 3);
            ,
            4,
        },
        .{
            \\var mul = fn(x, y): ret x*y; end;
            \\var apply = fn(func, a, b): func(a,b); end;
            \\apply(mul, 7, 3);
            ,
            21,
        },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        try test_integer_object(evaluated, exp[1]);
    }
}

fn test_func_object(object: *const Object.Object, expected: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // TODO: Refactor
    switch (object.*) {
        .literal_func => |func| {
            try std.testing.expectEqual(func.parameters.items.len, expected[1]);

            var params_buf = std.ArrayList(u8).init(alloc);
            for (func.parameters.items, 1..) |param, i| {
                try param.debug_string(&params_buf);
                if (i != func.parameters.items.len) {
                    try std.fmt.format(params_buf.writer(), ", ", .{});
                }
            }
            try std.testing.expectEqualStrings(try params_buf.toOwnedSlice(), expected[2]);

            var body_buf = std.ArrayList(u8).init(alloc);
            try func.body.debug_string(&body_buf);
            try std.testing.expectEqualStrings(try body_buf.toOwnedSlice(), expected[3]);
        },
        .named_func => |func| {
            try std.testing.expectEqual(func.parameters.items.len, expected[1]);

            var params_buf = std.ArrayList(u8).init(alloc);
            for (func.parameters.items, 1..) |param, i| {
                try param.debug_string(&params_buf);
                if (i != func.parameters.items.len) {
                    try std.fmt.format(params_buf.writer(), ", ", .{});
                }
            }
            try std.testing.expectEqualStrings(try params_buf.toOwnedSlice(), expected[2]);

            var body_buf = std.ArrayList(u8).init(alloc);
            try func.body.debug_string(&body_buf);
            try std.testing.expectEqualStrings(try body_buf.toOwnedSlice(), expected[3]);
        },
        else => |e| {
            try stderr.print("\nObject is not a Func. Detail:\n\t>>> {s}\n", .{e.err.msg});
            @panic("");
        },
    }
}

fn test_error_object(object: *const Object.Object, expected: []const u8) !void {
    switch (object.*) {
        .err => |err| {
            try std.testing.expectEqualStrings(err.msg, expected);
        },
        else => |e| {
            try stderr.print("\nObject is not an Error. Detail:\n\t>>> {s}\n", .{e.err.msg});
            @panic("");
        },
    }
}

fn test_integer_object(object: *const Object.Object, expected: i64) !void {
    switch (object.*) {
        .integer => |int| {
            try std.testing.expectEqual(int.value, expected);
        },
        else => |e| {
            try stderr.print("\nObject is not an Integer. Detail:\n\t>>> {s}\n", .{e.err.msg});
            @panic("");
        },
    }
}

fn test_string_object(object: *const Object.Object, expected: []const u8) !void {
    switch (object.*) {
        .string => |string| {
            try std.testing.expectEqualStrings(string.value, expected);
        },
        else => |e| {
            try stderr.print("\nObject is not a String. Detail:\n\t>>> {s}\n", .{e.err.msg});
            @panic("");
        },
    }
}

// fn test_array_object(object: *const Object.Object, expected: Object) !void {
//     switch (object.*) {
//         .array => |array| {
//             try std.testing.expectEqual(array.elements.items.len, expected.elements.items.len);
//             for (array.elements.itens, expected.elements.items) |item, exp| {
//                 try std.testing.expectEqual(item, exp);
//             }
//         },
//         else => |e| {
//             try stderr.print("\nObject is not an Array. Detail:\n\t>>> {s}\n", .{e.err.msg});
//             @panic("");
//         },
//     }
// }

fn test_boolean_object(object: *const Object.Object, expected: bool) !void {
    switch (object.*) {
        .boolean => |boo| {
            try std.testing.expectEqual(boo.value, expected);
        },
        else => |e| {
            try stderr.print("\nObject is not an Boolean. Detail:\n\t>>> {s}\n", .{e.err.msg});
            @panic("");
        },
    }
}

fn test_null_object(object: *const Object.Object) !void {
    switch (object.*) {
        .null => {
            try std.testing.expectEqualStrings(object.*.typename(), "Null");
        },
        else => |e| {
            try stderr.print("\nObject is not a Null. Detail:\n\t>>> {s}\n", .{e.err.msg});
            @panic("");
        },
    }
}

fn test_eval(input: []const u8) !*const Object.Object {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var alloc = arena.allocator();

    var env = try Environment.init(&alloc);

    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);

    const program_ast = try parser.parse();
    const evaluator = try Evaluator.init(&alloc);

    const evaluated = try evaluator.eval(program_ast, &env);

    // var buf = std.ArrayList(u8).init(std.testing.allocator);
    // defer buf.deinit();
    // try evaluated.inspect(&buf);
    // const str = try buf.toOwnedSlice();
    // std.debug.print("\ninspect >> {s}\n", .{str});

    return evaluated;
}
