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
        _ = try test_integer_object(evaluated, exp[1]);
    }
}

test "Test Boolean literal evaluation" {
    const expected = [_]struct { []const u8, bool }{
        .{ "true;", true },
        .{ "false;", false },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        _ = try test_boolean_object(evaluated, exp[1]);
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
        _ = try test_boolean_object(evaluated, exp[1]);
    }
}

test "Test Prefix - op with integers" {
    const expected = [_]struct { []const u8, i64 }{
        .{ "5;", 5 },
        .{ "10;", 10 },
        .{ "-10;", -10 },
        .{ "-999;", -999 },
    };

    for (expected) |exp| {
        const evaluated = try test_eval(exp[0]);
        _ = try test_integer_object(evaluated, exp[1]);
    }
}

fn test_integer_object(object: Object.Object, expected: i64) !bool {
    switch (object) {
        .integer => |int| {
            return int.value == expected;
        },
        else => {
            try stderr.print("Object is not an Integer\n", .{});
        },
    }

    return false;
}

fn test_boolean_object(object: Object.Object, expected: bool) !bool {
    switch (object) {
        .boolean => |boo| {
            return boo.value == expected;
        },
        else => {
            try stderr.print("Object is not a Boolean\n", .{});
        },
    }

    return false;
}

fn test_eval(input: []const u8) !Object.Object {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    const program_ast = try parser.parse();

    const evaluator = Evaluator{};

    return try evaluator.eval(program_ast);
}
