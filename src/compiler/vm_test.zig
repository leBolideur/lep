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

const ExpectedValue = union(enum) { integer: isize, boolean: bool };

test "Test the VM with Integers arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{ "1;", 1, 0 },
        .{ "2;", 2, 0 },
        .{ "6 + 6;", 12, 0 },
        .{ "5 - 6;", -1, 0 },
        .{ "6 * 6;", 36, 0 },
        .{ "6 / 6;", 1, 0 },
        .{ "50 / 2 * 2 + 10 - 5", 55, 0 },
        .{ "5 * (2 + 10)", 60, 0 },
        .{ "5 + 5 + 5 + 5 - 10", 10, 0 },
        .{ "2 * 2 * 2 * 2 * 2", 32, 0 },
        .{ "5 * 2 + 10", 20, 0 },
        .{ "5 + 2 * 10", 25, 0 },
        .{ "5 * (2 + 10)", 60, 0 },
    };

    try run_test(&alloc, test_cases, isize);
}

test "Test the VM with Booleans expressions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, bool, usize }{
        .{ "true;", true, 0 },
        .{ "false;", false, 0 },
    };

    try run_test(&alloc, test_cases, bool);
}

fn run_test(alloc: *const std.mem.Allocator, test_cases: anytype, comptime type_: type) !void {
    for (test_cases) |exp| {
        const root_node = try parse(exp[0], alloc);
        var compiler = try Compiler.init(alloc);
        try compiler.compile(root_node);

        var bytecode = compiler.bytecode();

        var vm = VM.new(alloc, bytecode);
        try vm.run();
        const last = vm.last_popped_element();

        try std.testing.expectEqual(exp[2], vm.stack.items.len);

        if (type_ == isize) {
            const expected = ExpectedValue{ .integer = exp[1] };
            try test_expected_object(expected, last);
        } else if (type_ == bool) {
            const expected = ExpectedValue{ .boolean = exp[1] };
            try test_expected_object(expected, last);
        }
    }
}

fn parse(input: []const u8, alloc: *const std.mem.Allocator) !ast.Node {
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, alloc);

    const root_node = try parser.parse();
    return root_node;
}

fn test_expected_object(expected: ExpectedValue, actual: ?*const Object) !void {
    try std.testing.expect(actual != null);

    switch (actual.?.*) {
        .integer => |int| {
            try std.testing.expectEqual(expected.integer, @as(isize, @intCast(int.value)));
        },
        .boolean => |boo| {
            try std.testing.expectEqual(expected.boolean, boo.value);
        },
        else => |other| {
            std.debug.print("Object is not an Integer, got: {any}\n", .{other});
        },
    }
}
