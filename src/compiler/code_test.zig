const std = @import("std");

const Code = @import("code.zig");

test "Test code.Make" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // Opcode, operands 2bytes, expected
    const expected = [_]struct { Code.Opcode, []const usize, []const u8 }{
        .{
            Code.Opcode.OpConstant,
            &[_]usize{65534},
            &[_]u8{ @as(u8, @intCast(@intFromEnum(Code.Opcode.OpConstant))), 255, 254 },
        },
        .{
            Code.Opcode.OpConstant,
            &[_]usize{128},
            &[_]u8{ @as(u8, @intCast(@intFromEnum(Code.Opcode.OpConstant))), 0, 128 },
        },
    };

    for (expected) |exp| {
        const instr = try Code.make(&alloc, exp[0], exp[1]);
        if (instr.len != exp[2].len) {
            std.debug.print(
                "\ninstruction has wrong length. want={d}, got={d}\n",
                .{ exp[2].len, instr.len },
            );
        }

        for (exp[2], 0..) |byte, i| {
            if (byte != instr[i]) {
                std.debug.print("\nwrong byte at pos {d}. want={d}, got={d}\n", .{ i, byte, instr[i] });
            }
        }
    }
}

test "Test Instruction.string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const expected =
        \\0000 OpConstant 1
        \\0003 OpConstant 2
        \\0006 OpConstant 65535
        \\
    ;

    const instructions = [3][]const u8{
        try Code.make(&alloc, Code.Opcode.OpConstant, &[1]usize{1}),
        try Code.make(&alloc, Code.Opcode.OpConstant, &[1]usize{2}),
        try Code.make(&alloc, Code.Opcode.OpConstant, &[1]usize{65535}),
    };

    var flattened_ = std.ArrayList(u8).init(alloc);
    for (instructions) |instr| {
        for (instr) |b| {
            try flattened_.append(b);
        }
    }
    const flattened = Code.Instructions{ .instructions = try flattened_.toOwnedSlice() };

    var definitions = try Code.Definitions.init(&alloc);
    const str = try flattened.to_string(&alloc, &definitions);

    try std.testing.expectEqualStrings(expected, str);
}

test "Test read operands" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // opcode, operands, bytes read
    const expected = [_]struct { Code.Opcode, []const usize, usize }{
        .{
            Code.Opcode.OpConstant,
            &[_]usize{65534},
            2,
        },
    };

    for (expected) |exp| {
        const instruction = try Code.make(&alloc, exp[0], exp[1]);

        const definitions = try Code.Definitions.init(&alloc);
        const def = try definitions.lookup(exp[0]);
        try std.testing.expect(def != null);

        var bytes_read: u8 = 0;
        const operands = try Code.read_operands(&alloc, def.?, instruction[1..], &bytes_read); // Skip opcode
        try std.testing.expectEqual(exp[2], bytes_read);

        for (operands, 0..) |exp_op, i| {
            try std.testing.expectEqual(exp[1][i], exp_op);
        }
    }
}
