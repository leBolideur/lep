const std = @import("std");

const MAX_OPERAND = 3;

pub const Instructions = struct {
    instructions: []const u8,

    pub fn string(self: Instructions, alloc: *std.mem.Allocator, definitions: *Definitions) []const u8 {
        for (self.instructions, 1..) |instr, i| {
            _ = i;
            const op_def = try definitions.*.lookup(@enumFromInt(instr));
            const operands = read_operands(alloc, op_def.?, instr);
        }
        return "";
    }
};

pub const Opcode = enum(u8) {
    OpConstant = 1,
    OpPush,
};

const OpDefinition = struct {
    name: []const u8,
    // TODO: Understand that
    operand_width: [MAX_OPERAND]u8 = [MAX_OPERAND]u8{ 0, 0, 0 },
    operand_count: u8,
};

pub const Definitions = struct {
    map: std.AutoHashMap(Opcode, OpDefinition),

    pub fn init(alloc: *const std.mem.Allocator) !Definitions {
        var map = std.AutoHashMap(Opcode, OpDefinition).init(alloc.*);
        try map.put(Opcode.OpConstant, OpDefinition{ .name = "OpConstant", .operand_count = 2 });

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

pub fn make(alloc: *const std.mem.Allocator, opcode: Opcode, operands: []const u8) ![]const u8 {
    const definitions = try Definitions.init(alloc);
    const def = definitions.map.get(opcode);
    if (def == null) return &.{};

    const operand_count = def.?.operand_count;
    const instr_ptr = try alloc.alloc(u8, operand_count + 1); // +1 for the opcode
    instr_ptr[0] = @intFromEnum(opcode);

    for (operands, 0..operands.len) |operand, i| {
        instr_ptr[i + 1] = operand;
    }

    return instr_ptr;
}

pub fn read_operands(alloc: *const std.mem.Allocator, def: OpDefinition, instr: []const u8) ![]const u8 {
    var operands_ptr = try alloc.*.alloc(u8, def.operand_count);

    for (0..def.operand_count) |i| {
        const operand = instr[i];
        operands_ptr[i] = operand;
    }

    return operands_ptr;
}
