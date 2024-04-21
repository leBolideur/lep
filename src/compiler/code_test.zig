const std = @import("std");

const Code = @import("code.zig");

test "Test code.Make" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();
    // Opcode, operands 2bytes, expected
    const tests = [_]struct { Code.Opcode, [2]u8, [3]u8 }{
        .{
            Code.Opcode.OpConstant,
            [_]u8{ 254, 255 }, //65534
            [3]u8{ @as(u8, @intCast(@intFromEnum(Code.Opcode.OpConstant))), 254, 255 },
        },
    };

    for (tests) |tt| {
        const instr = try Code.make(&alloc, tt[0], &tt[1]);
        if (instr.len != tt[2].len) {
            std.debug.print("instruction has wrong length. want={d}, got={d}", .{ tt[2].len, instr.len });
        }

        for (tt[2], 0..) |byte, i| {
            std.debug.print("byte: 0x{x} at pos {d}\n", .{ byte, i });
            if (byte != instr[i]) {
                std.debug.print("wrong byte at pos {d}. want={d}, got={d}", .{ i, byte, instr[i] });
            }
        }
    }
}
