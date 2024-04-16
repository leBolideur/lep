const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const ast = @import("ast.zig");
const Parser = @import("parser.zig").Parser;
const Object = @import("object.zig");
const Evaluator = @import("evaluator.zig").Evaluator;
const Environment = @import("environment.zig").Environment;

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

test "Test functions" {
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

test "Test functions call" {
    const expected = [_]struct { []const u8, i64 }{
        // .{ "var identity = fn(x): x; end identity(5);", 5 },
        // .{ "var identity = fn(x): ret x; end identity(5);", 5 },
        // .{ "var double = fn(x): x * 2; end double(5);", 10 },
        // .{ "var add = fn(x, y): x + y; end add(5, 5);", 10 },
        .{ "var add = fn(x, y): ret x + y; end add(5 + 5, add(5, 5));", 20 },
        // .{ "fn(x): x; end(5)", 5 },
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

    switch (object.*) {
        .func => |func| {
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
            // @panic("");
        },
    }
}

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
        .null => |nu| {
            try std.testing.expectEqual(nu.value, null);
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
