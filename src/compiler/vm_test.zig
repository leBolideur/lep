const std = @import("std");

const Lexer = @import("../interpreter/lexer/lexer.zig").Lexer;
const Parser = @import("../interpreter/parser/parser.zig").Parser;
const Object = @import("../interpreter/intern/object.zig").Object;
const ast = @import("../interpreter/ast/ast.zig");

const comp_imp = @import("compiler.zig");
const Compiler = comp_imp.Compiler;
// const Bytecode = comp_imp.Bytecode;

test "Test the VM with Integers arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const test_cases = [_]struct { []const u8, usize }{
        .{ "1;", 1 },
        .{ "2;", 2 },
        .{ "1 + 2;", 2 }, //FIXME
    };

    try run_test(&alloc, test_cases);
}

fn run_test(alloc: *const std.mem.Allocator, test_cases: anytype) !void {
    for (test_cases) |exp| {
        const root_node = try parse(exp[0], alloc);
        var compiler = Compiler.init(alloc);
        try compiler.compile(root_node);

        const bytecode = compiler.bytecode();
        _ = bytecode;

        // var vm = try VM.new(bytecode);
    }
}

fn parse(input: []const u8, alloc: *const std.mem.Allocator) !ast.Node {
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, alloc);

    const root_node = try parser.parse();
    return root_node;
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
