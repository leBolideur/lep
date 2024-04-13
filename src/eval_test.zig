const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const ast = @import("ast.zig");
const Parser = @import("parser.zig").Parser;
const Object = @import("object.zig");
const Evaluator = @import("evaluator.zig").Evaluator;

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
        .{ "if (true): 10; end;", 10 },
        .{ "if (false): 10; end;", null },
        // .{ "if (1): 10; end;", 10 },
        .{ "if (1 < 2): 10; end;", 10 },
        .{ "if (1 > 2): 10; end;", null },
        .{ "if (1 > 2): 10; else: 20; end;", 20 },
        .{ "if (1 < 2): 10; else: 20; end;", 10 },
    };

    // if (5 * 5 + 10 > 34): 99; else: 100; end;
    // if ((1000 / 2) + 250 * 2 == 1000): 9999; end;

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        switch (evaluated) {
            .integer => try test_integer_object(evaluated, exp[1].?),
            .null => {},
            else => unreachable,
        }
    }
}

fn test_integer_object(object: Object.Object, expected: i64) !void {
    switch (object) {
        .integer => |int| {
            try std.testing.expectEqual(int.value, expected);
        },
        else => {
            try stderr.print("Object is not an Integer\n", .{});
        },
    }
}

fn test_boolean_object(object: Object.Object, expected: bool) !void {
    switch (object) {
        .boolean => |boo| {
            try std.testing.expectEqual(boo.value, expected);
        },
        else => {
            try stderr.print("Object is not a Boolean\n", .{});
        },
    }
}

fn test_null_object(object: Object.Object) !void {
    switch (object) {
        .null => |boo| {
            try std.testing.expectEqual(boo.value, null);
        },
        else => {
            try stderr.print("Object is supposed to be a Null one\n", .{});
        },
    }
}

fn test_eval(input: []const u8) !Object.Object {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    const program_ast = try parser.parse();

    const evaluator = try Evaluator.init(&alloc);

    return try evaluator.eval(program_ast);
}
