const std = @import("std");

const CodeError = error{ OpNoDefinition, ArrayListError, OutOfMemory };

pub const Instructions = struct {
    instructions: []const u8,

    pub fn string(
        self: Instructions,
        alloc: *std.mem.Allocator,
        definitions: *Definitions,
    ) CodeError![]const u8 {
        var offset: u8 = 0;
        var buf: []const u8 = undefined;
        // std.debug.print("instructions: {s}\n", .{self.instructions});

        while (offset < self.instructions.len) {
            const instr = self.instructions[offset];
            // std.debug.print("instr: {c}\n", .{instr});

            const op_def = try definitions.*.lookup(@enumFromInt(instr));
            const def: OpDefinition = op_def orelse return CodeError.OpNoDefinition;
            const width = def.operand_count;

            const operands = self.instructions[(offset + 1)..(offset + width)];
            // std.debug.print("\noperand: {any}\twidth: {d}", .{ operands[0], width });
            // const fmt = try std.fmt.allocPrint(alloc.*, "{d:0>4} {s} {d}\n", .{ offset, def.name, operands[0] });
            // for (fmt) |c| try str.append(c);
            //
            buf = try read_operands(alloc, def, operands);
            std.debug.print("operands read: {d}\n", .{buf.len});

            offset += width + 1; // +1 to jump opcode
        }

        return buf;
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
        try map.put(Opcode.OpConstant, OpDefinition{ .name = "OpConstant", .operand_widths = &[_]u8{2}, .operand_count = 1 });

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

pub fn make(alloc: *const std.mem.Allocator, opcode: Opcode, operands: []const usize) ![]const u8 {
    const definitions = try Definitions.init(alloc);
    const def_ = definitions.map.get(opcode);
    const def = def_ orelse return CodeError.OpNoDefinition;

    var instr_len: u8 = 0;
    for (def.operand_widths) |width| {
        instr_len += width;
    }
    std.debug.print("operandS: {d}", .{operands});

    const instr_ptr = try alloc.alloc(u8, instr_len + 1); // +1 for the opcode
    instr_ptr[0] = @intFromEnum(opcode);

    var offset: u8 = 1;
    for (operands, 0..) |operand, i| {
        std.debug.print("i={d} - ", .{i});
        const width = def.operand_widths[i];
        switch (width) {
            2 => {
                instr_ptr[offset] = @as(u8, @intCast((operand & 0xFF00 >> 8)));
                std.debug.print("1/ operand: {d} -> {d}\n", .{ operand, instr_ptr[offset] });
                instr_ptr[offset + 1] = @as(u8, @intCast(operand & 0x00FF));
                std.debug.print("2/ operand: {d} -> {d}\n", .{ operand, instr_ptr[offset + 1] });
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
) CodeError![]const u8 {
    var operands = std.ArrayList(u8).init(alloc.*);
    // var operands = alloc.alloc(u8, def.operand_count);

    var offset: u8 = 0;
    for (def.operand_widths) |width| {
        switch (width) {
            2 => {
                const operand = instruction[offset..2];
                // operands.items[i] = operand;
                for (operand) |b| {
                    operands.append(b) catch return CodeError.ArrayListError;
                }
            },
            else => unreachable,
        }

        offset += width;
    }

    return try operands.toOwnedSlice();
}
