const std = @import("std");

pub const Opcode = enum(u8) {
    OpConstant = 1,

    OpSetGlobal,
    OpGetGlobal,

    OpArray,
    OpHash,
    OpIndex,

    OpTrue,
    OpFalse,
    OpNull,

    OpAdd,
    OpSub,
    OpMul,
    OpDiv,

    OpEq,
    OpNotEq,
    OpGT,
    OpMinus,

    OpBang,
    OpPop,

    OpJumpNotTrue,
    OpJump,
};

pub const OpDefinition = struct {
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
        try map.put(
            Opcode.OpSetGlobal,
            OpDefinition{
                .name = "OpSetGlobal",
                .operand_widths = &[_]u8{2},
                .operand_count = 1,
            },
        );
        try map.put(
            Opcode.OpGetGlobal,
            OpDefinition{
                .name = "OpGetGlobal",
                .operand_widths = &[_]u8{2},
                .operand_count = 1,
            },
        );
        try map.put(
            Opcode.OpArray,
            OpDefinition{
                .name = "OpArray",
                .operand_widths = &[_]u8{2},
                .operand_count = 1,
            },
        );
        try map.put(
            Opcode.OpHash,
            OpDefinition{
                .name = "OpHash",
                .operand_widths = &[_]u8{2},
                .operand_count = 1,
            },
        );
        try map.put(
            Opcode.OpIndex,
            OpDefinition{
                .name = "OpIndex",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpTrue,
            OpDefinition{
                .name = "OpTrue",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpFalse,
            OpDefinition{
                .name = "OpFalse",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpNull,
            OpDefinition{
                .name = "OpNull",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpAdd,
            OpDefinition{
                .name = "OpAdd",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpSub,
            OpDefinition{
                .name = "OpSub",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpMul,
            OpDefinition{
                .name = "OpMul",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpDiv,
            OpDefinition{
                .name = "OpDiv",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpEq,
            OpDefinition{
                .name = "OpEq",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpNotEq,
            OpDefinition{
                .name = "OpNotEq",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpGT,
            OpDefinition{
                .name = "OpGT",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpMinus,
            OpDefinition{
                .name = "OpMinus",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpBang,
            OpDefinition{
                .name = "OpBang",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpPop,
            OpDefinition{
                .name = "OpPop",
                .operand_widths = &[_]u8{0},
                .operand_count = 0,
            },
        );
        try map.put(
            Opcode.OpJumpNotTrue,
            OpDefinition{
                .name = "OpJumpNotTrue",
                .operand_widths = &[_]u8{2},
                .operand_count = 1,
            },
        );
        try map.put(
            Opcode.OpJump,
            OpDefinition{
                .name = "OpJump",
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
