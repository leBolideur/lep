const std = @import("std");

const ast = @import("../interpreter/ast/ast.zig");
const object_import = @import("../interpreter/intern/object.zig");
const Object = object_import.Object;

const code = @import("code.zig");

const eval_utils = @import("../interpreter/utils/eval_utils.zig");

pub const Bytecode = struct {
    instructions: code.Instructions,
    constants: std.ArrayList(*const Object),
};

pub const Compiler = struct {
    instructions: code.Instructions,
    constants: std.ArrayList(*const Object),

    alloc: *const std.mem.Allocator,

    pub fn init(alloc: *const std.mem.Allocator) Compiler {
        var constants = std.ArrayList(*const Object).init(alloc.*);
        var instructions = std.ArrayList(u8).init(alloc.*);

        return Compiler{
            .instructions = code.Instructions{ .instructions = instructions },
            .constants = constants,

            .alloc = alloc,
        };
    }

    pub fn compile(self: *Compiler, node: ast.Node) !void {
        switch (node) {
            .program => |program| {
                for (program.statements.items) |st| {
                    try self.parse_statement(st);
                }
            },
            else => unreachable,
        }
    }

    fn parse_statement(self: *Compiler, st: ast.Statement) !void {
        switch (st) {
            .expr_statement => |expr_st| {
                try self.parse_expression(expr_st.expression);
            },
            else => unreachable,
        }
    }

    fn parse_expression(self: *Compiler, expr: *const ast.Expression) !void {
        switch (expr.*) {
            .integer => |int| {
                try self.parse_integer(int);
            },
            .infix_expr => |infix| {
                const left = try self.parse_expression(infix.left_expr);
                const right = try self.parse_expression(infix.right_expr);
                _ = left;
                _ = right;
            },
            else => unreachable,
        }
    }

    fn parse_integer(self: *Compiler, int: ast.IntegerLiteral) !void {
        const object = try eval_utils.new_integer(self.alloc, int.value);
        const identifier = try self.add_constant(object);

        // Cast to []usize
        const operands = &[_]usize{identifier};
        const pos = try self.emit(code.Opcode.OpConstant, operands);

        _ = pos;
    }

    pub fn bytecode(self: Compiler) Bytecode {
        return Bytecode{
            .instructions = self.instructions,
            .constants = self.constants,
        };
    }

    fn add_constant(self: *Compiler, object: *const Object) !usize {
        try self.constants.append(object);

        // return the index, the constant identifier
        return self.constants.items.len - 1;
    }

    fn emit(self: *Compiler, opcode: code.Opcode, operands: []const usize) !usize {
        const instruction = try code.make(self.alloc, opcode, operands);
        std.debug.print("emit: {any}\n", .{instruction});

        const pos = try self.add_instruction(instruction);

        return pos;
    }

    fn add_instruction(self: *Compiler, instruction: []const u8) !usize {
        // Starting position of the instruction
        const pos_new_instr = self.instructions.instructions.items.len;
        for (instruction) |b| {
            try self.instructions.instructions.append(b);
        }

        return pos_new_instr;
    }
};
