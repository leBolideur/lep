const std = @import("std");

const Lexer = @import("../interpreter/lexer/lexer.zig").Lexer;
const Parser = @import("../interpreter/parser/parser.zig").Parser;
const Object = @import("../interpreter/intern/object.zig").Object;
const ast = @import("../interpreter/ast/ast.zig");

const code = @import("code.zig");

const comp_imp = @import("compiler.zig");
const Compiler = comp_imp.Compiler;
// const Bytecode = comp_imp.Bytecode;

const VM = @import("vm.zig").VM;

test "Test the VM with Integers arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, usize, usize }{
        .{ "1;", 1, 0 },
        .{ "2;", 2, 0 },
        .{ "6 + 6;", 12, 0 },
    };

    try run_test(&alloc, test_cases);
}

fn run_test(alloc: *const std.mem.Allocator, test_cases: anytype) !void {
    for (test_cases) |exp| {
        const root_node = try parse(exp[0], alloc);
        var compiler = try Compiler.init(alloc);
        try compiler.compile(root_node);

        var bytecode = compiler.bytecode();

        var vm = VM.new(alloc, bytecode);
        try vm.run();
        const last = vm.last_popped_element();

        try std.testing.expectEqual(exp[2], vm.stack.items.len);
        try test_integer_object(exp[1], last);
    }
}

fn parse(input: []const u8, alloc: *const std.mem.Allocator) !ast.Node {
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, alloc);

    const root_node = try parser.parse();
    return root_node;
}

fn test_integer_object(expected: usize, actual: ?*const Object) !void {
    try std.testing.expect(actual != null);

    switch (actual.?.*) {
        .integer => |int| {
            try std.testing.expectEqual(expected, @as(usize, @intCast(int.value)));
        },
        else => |other| {
            std.debug.print("Object is not an Integer, got: {any}\n", .{other});
        },
    }
}
