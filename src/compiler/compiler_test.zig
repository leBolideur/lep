const std = @import("std");

const Lexer = @import("../interpreter/lexer/lexer.zig").Lexer;
const Parser = @import("../interpreter/parser/parser.zig").Parser;
const Object = @import("../interpreter/intern/object.zig").Object;
const ast = @import("../interpreter/ast/ast.zig");

const code = @import("code.zig");

const comp_imp = @import("compiler.zig");
const Compiler = comp_imp.Compiler;
// const Bytecode = comp_imp.Bytecode;

test "Test the compiler with Integers arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, [3][]const u8, [2]i64 }{
        .{
            "1 + 2;",
            [_][]const u8{
                try code.make(&alloc, code.Opcode.OpConstant, &[_]usize{0}),
                try code.make(&alloc, code.Opcode.OpConstant, &[_]usize{1}),
                try code.make(&alloc, code.Opcode.OpAdd, &[_]usize{}),
            },
            [_]i64{ 1, 2 },
        },
    };

    try run_test(&alloc, test_cases);
}

fn run_test(alloc: *const std.mem.Allocator, test_cases: anytype) !void {
    for (test_cases) |exp| {
        const root_node = try parse(exp[0], alloc);
        var compiler = try Compiler.init(alloc);
        try compiler.compile(root_node);

        const bytecode = compiler.bytecode();
        try test_instructions(alloc, exp[1], bytecode.instructions);
        try test_integer_constants(exp[2], bytecode.constants);
    }
}

fn parse(input: []const u8, alloc: *const std.mem.Allocator) !ast.Node {
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, alloc);

    const root_node = try parser.parse();
    return root_node;
}

fn test_instructions(
    alloc: *const std.mem.Allocator,
    expected: [3][]const u8,
    actual: code.Instructions,
) !void {
    var flattened_ = std.ArrayList(u8).init(alloc.*);
    for (expected) |exp| {
        for (exp) |b| {
            try flattened_.append(b);
        }
    }

    const flattened = try flattened_.toOwnedSlice();

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
