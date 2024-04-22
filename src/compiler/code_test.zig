const std = @import("std");

const Code = @import("code.zig");

test "Test code.Make" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // Opcode, operands 2bytes, expected
    const expected = [_]struct { Code.Opcode, [2]u8, [3]u8 }{
        .{
            Code.Opcode.OpConstant,
            [_]u8{ 254, 255 }, //65534
            [3]u8{ @as(u8, @intCast(@intFromEnum(Code.Opcode.OpConstant))), 254, 255 },
        },
    };

    for (expected) |exp| {
        const instr = try Code.make(&alloc, exp[0], &exp[1]);
        if (instr.len != exp[2].len) {
            std.debug.print(
                "instruction has wrong length. want={d}, got={d}",
                .{ exp[2].len, instr.len },
            );
        }

        for (exp[2], 0..) |byte, i| {
            // std.debug.print("byte > exp: 0x{x}, instr: 0x{x} at pos {d}\n", .{ byte, instr[i], i });
            if (byte != instr[i]) {
                std.debug.print("wrong byte at pos {d}. want={d}, got={d}", .{ i, byte, instr[i] });
            }
        }
    }
}

test "Test MiniDisassembler" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const expected =
        \\\0000 OpConstant 1
        \\\0003 OpConstant 2
        \\\0006 OpConstant 65535
    ;

    const instructions = [3][]const u8{
        try Code.make(&alloc, Code.Opcode.OpConstant, &[1]u8{1}),
        try Code.make(&alloc, Code.Opcode.OpConstant, &[1]u8{2}),
        try Code.make(&alloc, Code.Opcode.OpConstant, &[2]u8{ 254, 255 }),
    };

    var flattened_ = std.ArrayList(u8).init(alloc);
    for (instructions) |instr| {
        for (instr) |b| {
            try flattened_.append(b);
        }
    }
    const flattened = Code.Instructions{ .instructions = try flattened_.toOwnedSlice() };

    var definitions = try Code.Definitions.init(&alloc);
    const str = flattened.string(&alloc, &definitions);

    try std.testing.expectEqualStrings(expected, str);
}

test "Test read operands" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // opcode, operands, bytes read
    const expected = [_]struct { Code.Opcode, [2]u8, usize }{
        .{
            Code.Opcode.OpConstant,
            [_]u8{ 254, 255 }, //65534
            2,
        },
    };

    for (expected) |exp| {
        const instruction = try Code.make(&alloc, exp[0], &exp[1]);

        const definitions = try Code.Definitions.init(&alloc);
        const def = try definitions.lookup(exp[0]);
        try std.testing.expect(def != null);

        const operands_read = try Code.read_operands(&alloc, def.?, instruction[1..]);
        try std.testing.expectEqual(exp[2], operands_read.len);

        for (exp[1], 0..) |operand, i| {
            try std.testing.expectEqual(operand, operands_read[i]);
        }
    }
}
