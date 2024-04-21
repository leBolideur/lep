const std = @import("std");

const MAX_OPERAND = 3;

pub const Instructions = struct {
    instructions: []const u8,
};

pub const Opcode = enum(u8) {
    OpConstant = 1,
    OpPush,
};

// pub const OpConstant = struct {};

pub const OpDefinition = struct {
    name: []const u8,
    operand_width: [MAX_OPERAND]u8 = [MAX_OPERAND]u8{ 0, 0, 0 },
    operand_nb: u8,
};

pub const Definitions = struct {
    map: std.AutoHashMap(Opcode, OpDefinition),

    pub fn init(alloc: *const std.mem.Allocator) !Definitions {
        var map = std.AutoHashMap(Opcode, OpDefinition).init(alloc.*);
        try map.put(Opcode.OpConstant, OpDefinition{ .name = "OpConstant", .operand_nb = 2 });

        return Definitions{
            .map = map,
        };
    }

    pub fn lookup(self: Definitions, opcode: u8) !?OpDefinition {
        const def = self.map.get(opcode);
        return def.? orelse {
            std.debug.print("Unknown opcode {d}\n", .{opcode});
            return null;
        };
    }
};

pub fn make(alloc: *const std.mem.Allocator, opcode: Opcode, operands: []const u8) ![]u8 {
    const definitions = try Definitions.init(alloc);
    const def = definitions.map.get(opcode);
    if (def == null) return &.{};

    const operand_nb = def.?.operand_nb;
    const instr_ptr = try alloc.alloc(u8, operand_nb + 1); // +1 for the opcode
    instr_ptr[0] = @intFromEnum(opcode);

    for (operands, 0..operands.len) |operand, i| {
        instr_ptr[i + 1] = operand;
    }

    return instr_ptr;
}
