const std = @import("std");

const CodeError = error{ OpNoDefinition, ArrayListError, OutOfMemory };

pub const Instructions = struct {
    instructions: std.ArrayList(u8),

    pub fn to_string(
        self: Instructions,
        alloc: *std.mem.Allocator,
        definitions: *Definitions,
    ) CodeError![]const u8 {
        const instructions = try self.instructions.toOwnedSlice();
        var offset: u8 = 0;
        var string = std.ArrayList(u8).init(alloc.*);

        while (offset < instructions.len) {
            const instr = instructions[offset];

            const op_def = try definitions.*.lookup(@enumFromInt(instr));
            const def: OpDefinition = op_def orelse return CodeError.OpNoDefinition;

            var bytes_read: u8 = 0;
            const operands = instructions[(offset + 1)..]; // +1 to skip opcode
            const operands_read = try read_operands(alloc, def, operands, &bytes_read);

            try std.fmt.format(string.writer(), "{d:0>4} {s}", .{ offset, def.name });
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
};

pub const Opcode = enum(u8) {
    OpConstant = 1,
    OpPush,
};

const OpDefinition = struct {
    name: []const u8,
    operand_widths: []const u8,
    operand_count: u8,
};

pub const Definitions = struct {
    map: std.AutoHashMap(Opcode, OpDefinition),

    pub fn init(alloc: *const std.mem.Allocator) !Definitions {
        var map = std.AutoHashMap(Opcode, OpDefinition).init(alloc.*);
        try map.put(
            Opcode.OpConstant,
            OpDefinition{
                .name = "OpConstant",
                .operand_widths = &[_]u8{2},
                .operand_count = 1,
            },
        );

        return Definitions{
            .map = map,
        };
    }

    pub fn lookup(self: Definitions, opcode: Opcode) !?OpDefinition {
        const def = self.map.get(opcode);
        return def orelse {
            std.debug.print("Unknown opcode {?}\n", .{opcode});
            return null;
        };
    }
};

pub fn make(
    alloc: *const std.mem.Allocator,
    opcode: Opcode,
    operands: []const usize,
) CodeError![]const u8 {
    const definitions = try Definitions.init(alloc);
    const def_ = definitions.map.get(opcode);
    const def = def_ orelse return CodeError.OpNoDefinition;

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
) CodeError![]const usize {
    var offset: u8 = 0;
    var operands = std.ArrayList(usize).init(alloc.*);

    for (def.operand_widths) |width| {
        switch (width) {
            2 => {
                var left: usize = @intCast(instruction[offset]);
                var result: usize = (left << 8) | instruction[offset + 1];
                try operands.append(result);
            },
            else => unreachable,
        }

        offset += width;
    }

    bytes_read.* = offset;
    return operands.toOwnedSlice();
}
