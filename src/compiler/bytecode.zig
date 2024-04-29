const std = @import("std");

const opcode_import = @import("opcode.zig");
const Opcode = opcode_import.Opcode;
const Definitions = opcode_import.Definitions;
const OpDefinition = opcode_import.OpDefinition;

const BytecodeError = error{ OpNoDefinition, ArrayListError, OutOfMemory };

pub const Instructions = struct {
    instructions: std.ArrayList(u8),

    pub fn init(alloc: *const std.mem.Allocator) !*const Instructions {
        const ptr = try alloc.*.create(Instructions);
        ptr.* = Instructions{
            .instructions = std.ArrayList(u8).init(alloc.*),
        };

        return ptr;
    }
};

pub fn to_string(
    instructions_: *std.ArrayList(u8),
    alloc: *const std.mem.Allocator,
    definitions: *const Definitions,
) BytecodeError![]const u8 {
    const instructions = try instructions_.toOwnedSlice();
    var offset: u8 = 0;
    var string = std.ArrayList(u8).init(alloc.*);

    while (offset < instructions.len) {
        const instr = instructions[offset];

        const op_def = try definitions.*.lookup(@enumFromInt(instr));
        const def: OpDefinition = op_def orelse return BytecodeError.OpNoDefinition;

        var bytes_read: u8 = 0;
        const operands = instructions[(offset + 1)..]; // +1 to skip opcode
        const operands_read = try read_operands(alloc, def, operands, &bytes_read);

        try std.fmt.format(string.writer(), "{d:0>4} {s}", .{ offset, def.name });
        if (bytes_read == 0) {
            try std.fmt.format(string.writer(), "\n", .{});
        }
        for (operands_read, 1..) |op, i| {
            try std.fmt.format(string.writer(), " {d}", .{op});
            if (i != operands_read.len - 1) {
                try std.fmt.format(string.writer(), "\n", .{});
            }
        }

        offset += bytes_read + 1; // +1 to jump opcode
    }

    return try string.toOwnedSlice();
}

pub fn make(
    alloc: *const std.mem.Allocator,
    opcode: Opcode,
    operands: []const usize,
) BytecodeError![]const u8 {
    const definitions = try Definitions.init(alloc);
    const def_ = definitions.map.get(opcode);
    const def = def_ orelse return BytecodeError.OpNoDefinition;

    var instr_len: u8 = 0;
    for (def.operand_widths) |width| {
        instr_len += width;
    }

    const instr_ptr = try alloc.alloc(u8, instr_len + 1); // +1 for the opcode
    instr_ptr[0] = @intFromEnum(opcode);

    var offset: u8 = 1;
    for (operands, 0..) |operand, i| {
        const width = def.operand_widths[i];
        switch (width) {
            2 => {
                instr_ptr[offset] = @as(u8, @intCast((operand & 0xFF00) >> 8));
                instr_ptr[offset + 1] = @as(u8, @intCast(operand & 0x00FF));
            },
            else => unreachable,
        }

        offset += width;
    }

    return instr_ptr;
}

pub fn read_operands(
    alloc: *const std.mem.Allocator,
    def: OpDefinition,
    instruction: []const u8,
    bytes_read: *u8,
) BytecodeError![]const usize {
    var offset: u8 = 0;
    var operands = std.ArrayList(usize).init(alloc.*);

    for (def.operand_widths) |width| {
        switch (width) {
            2 => {
                try operands.append(read_u16(instruction));
            },
            0 => {},
            else => unreachable,
        }

        offset += width;
    }

    bytes_read.* = offset;
    return operands.toOwnedSlice();
}

pub fn read_u16(raw: []const u8) u16 {
    const left: usize = @intCast(raw[0]);
    const result: usize = (left << 8) | raw[1];

    return @as(u16, @intCast(result));
}
