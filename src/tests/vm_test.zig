const std = @import("std");

const interpreter = @import("interpreter");
const common = @import("common");
const compiler_ = @import("compiler");

const Lexer = common.lexer.Lexer;
const Parser = common.parser.Parser;
const Object = common.object.Object;
const ast = common.ast;

const opcode = compiler_.opcode;

const Compiler = compiler_.compiler.Compiler;

const VM = compiler_.vm.VM;

const ExpectedValue = union(enum) { integer: isize, boolean: bool };

test "Test the VM with Integers arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{ "1;", 1, 0 },
        .{ "2;", 2, 0 },
        .{ "-12;", -12, 0 },
        .{ "-50 + 100 + -50", 0, 0 },
        .{ "(5 + 10 * 2 + 15 / 3) * 2 + -10", 50, 0 },
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
        .{ "1 < 2;", true, 0 },
        .{ "1 > 2", false, 0 },
        .{ "1 < 1", false, 0 },
        .{ "1 > 1", false, 0 },
        .{ "1 == 1", true, 0 },
        .{ "1 != 1", false, 0 },
        .{ "1 == 2", false, 0 },
        .{ "1 != 2", true, 0 },
        .{ "true == true", true, 0 },
        .{ "false == false", true, 0 },
        .{ "true == false", false, 0 },
        .{ "true != false", true, 0 },
        .{ "false != true", true, 0 },
        .{ "(1 < 2) == true", true, 0 },
        .{ "(1 < 2) == false", false, 0 },
        .{ "(1 > 2) == true", false, 0 },
        .{ "(1 > 2) == false", true, 0 },
        .{ "!true", false, 0 },
        .{ "!false", true, 0 },
        .{ "!!true", true, 0 },
        .{ "!!false", false, 0 },
    };

    try run_test(&alloc, test_cases, bool);
}

test "Test the VM with Conditionals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{ "if (true): 10; end", 10, 0 },
        .{ "if (true): 10; else: 20; end", 10, 0 },
        .{ "if (false): 10; else: 20; end", 20, 0 },
        .{ "if (1 < 2): 10; end", 10, 0 },
        .{ "if (1 < 2): 10; else: 20; end", 10, 0 },
        .{ "if (1 > 2): 10; else: 20; end", 20, 0 },
    };

    try run_test(&alloc, test_cases, isize);
}

fn run_test(alloc: *const std.mem.Allocator, test_cases: anytype, comptime type_: type) !void {
    for (test_cases) |exp| {
        const root_node = try parse(exp[0], alloc);
        var compiler = try Compiler.init(alloc);
        try compiler.compile(root_node);

        const bytecode = compiler.get_bytecode();

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
