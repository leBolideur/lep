const std = @import("std");

const Lexer = @import("../interpreter/lexer/lexer.zig").Lexer;
const Parser = @import("../interpreter/parser/parser.zig").Parser;
const Object = @import("../interpreter/intern/object.zig").Object;

const code = @import("code.zig");
const Compiler = @import("compiler.zig").Compiler;

test "Test the compiler with Integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const expected = [_]struct { []const u8, [2][]const u8, [2]i64 }{
        .{
            "1 + 2;",
            [_][]const u8{
                code.make(&alloc, code.Opcode.OpConstant, &[_]usize{1}) catch "",
                code.make(&alloc, code.Opcode.OpConstant, &[_]usize{2}) catch "",
            },
            [_]i64{ 1, 2 },
        },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var parser = try Parser.init(&lexer, &alloc);

        const root_node = try parser.parse();

        var compiler = Compiler.init(&alloc);
        try compiler.compile(root_node);

        const bytecode = compiler.bytecode();
        try test_instructions(&alloc, exp[1], bytecode.instructions);
        try test_integer_constants(exp[2], bytecode.constants);
    }
}

fn test_instructions(
    alloc: *const std.mem.Allocator,
    expected: [2][]const u8,
    actual: code.Instructions,
) !void {
    var flattened_ = std.ArrayList(u8).init(alloc.*);
    for (expected) |exp| {
        for (exp) |b| {
            try flattened_.append(b);
        }
    }

    const flattened = try flattened_.toOwnedSlice();

    // std.debug.print("flattened: {any}\n", .{flattened});
    // std.debug.print("actual: {any}\n", .{actual.instructions});

    try std.testing.expectEqual(flattened.len, actual.instructions.items.len);

    for (flattened, actual.instructions.items) |exp, act| {
        try std.testing.expectEqual(exp, act);
    }
}

fn test_integer_constants(expected: [2]i64, actual: std.ArrayList(*const Object)) !void {
    try std.testing.expectEqual(expected.len, actual.items.len);

    for (expected, actual.items) |exp, obj| {
        switch (obj.*) {
            .integer => |int| {
                try std.testing.expectEqual(exp, int.value);
            },
            else => |other| {
                std.debug.print("Object is not an Integer, got: {any}\n", .{other});
            },
        }
    }
}
