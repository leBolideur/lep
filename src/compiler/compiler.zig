const std = @import("std");

const common = @import("common");
// const interpreter = @import("interpreter.zig");

const ast = common.ast;
const object_import = common.object;
const Object = object_import.Object;

const bytecode_ = @import("bytecode.zig");

const Opcode = @import("opcode.zig").Opcode;

const eval_utils = common.eval_utils;

const INFIX_OP = enum { SUM, SUB, MUL, DIV, LT, GT, LTE, GTE, EQ, NOT_EQ };

const CompilerError = error{
    OutOfMemory,
    ObjectCreation,
    MakeInstr,
    UnknownOperator,
};

pub const Bytecode = struct {
    instructions: bytecode_.Instructions,
    constants: std.ArrayList(*const Object),
};

const stderr = std.io.getStdErr().writer();

pub const Compiler = struct {
    instructions: bytecode_.Instructions,
    constants: std.ArrayList(*const Object),

    infix_op_map: std.StringHashMap(INFIX_OP),

    alloc: *const std.mem.Allocator,

    pub fn init(alloc: *const std.mem.Allocator) CompilerError!Compiler {
        var infix_op_map = std.StringHashMap(INFIX_OP).init(alloc.*);
        try infix_op_map.put("+", INFIX_OP.SUM);
        try infix_op_map.put("-", INFIX_OP.SUB);
        try infix_op_map.put("*", INFIX_OP.MUL);
        try infix_op_map.put("/", INFIX_OP.DIV);
        try infix_op_map.put("<", INFIX_OP.LT);
        try infix_op_map.put(">", INFIX_OP.GT);
        try infix_op_map.put("<=", INFIX_OP.LTE);
        try infix_op_map.put(">=", INFIX_OP.GTE);
        try infix_op_map.put("==", INFIX_OP.EQ);
        try infix_op_map.put("!=", INFIX_OP.NOT_EQ);

        const constants = std.ArrayList(*const Object).init(alloc.*);
        const instructions = std.ArrayList(u8).init(alloc.*);

        return Compiler{
            .instructions = bytecode_.Instructions{ .instructions = instructions },
            .constants = constants,

            .infix_op_map = infix_op_map,

            .alloc = alloc,
        };
    }

    pub fn compile(self: *Compiler, node: ast.Node) CompilerError!void {
        switch (node) {
            .program => |program| {
                for (program.statements.items) |st| {
                    try self.parse_statement(st);
                }
            },
            else => unreachable,
        }
    }

    fn parse_statement(self: *Compiler, st: ast.Statement) CompilerError!void {
        switch (st) {
            .expr_statement => |expr_st| {
                try self.parse_expr_statement(expr_st.expression);
                _ = try self.emit(Opcode.OpPop, &[_]usize{});
            },
            else => unreachable,
        }
    }

    fn parse_expr_statement(self: *Compiler, expr: *const ast.Expression) CompilerError!void {
        switch (expr.*) {
            .integer => |int| {
                try self.parse_integer(int);
            },
            .boolean => |boo| {
                if (boo.value) {
                    _ = try self.emit(Opcode.OpTrue, &[_]usize{});
                } else {
                    _ = try self.emit(Opcode.OpFalse, &[_]usize{});
                }
            },
            .infix_expr => |infix| {
                const op_ = infix.operator;
                const op = self.infix_op_map.get(op_);
                // Reordering for < operator
                if (op == INFIX_OP.LT) {
                    // FIRST compile right THEN left (inverse order of push on stack)
                    try self.parse_expr_statement(infix.right_expr);
                    try self.parse_expr_statement(infix.left_expr);

                    _ = try self.emit(Opcode.OpGT, &[_]usize{});

                    return;
                }

                // Normal order, left then right
                try self.parse_expr_statement(infix.left_expr);
                try self.parse_expr_statement(infix.right_expr);

                switch (op.?) {
                    INFIX_OP.SUM => {
                        _ = try self.emit(Opcode.OpAdd, &[_]usize{});
                    },
                    INFIX_OP.SUB => {
                        _ = try self.emit(Opcode.OpSub, &[_]usize{});
                    },
                    INFIX_OP.MUL => {
                        _ = try self.emit(Opcode.OpMul, &[_]usize{});
                    },
                    INFIX_OP.DIV => {
                        _ = try self.emit(Opcode.OpDiv, &[_]usize{});
                    },
                    INFIX_OP.EQ => {
                        _ = try self.emit(Opcode.OpEq, &[_]usize{});
                    },
                    INFIX_OP.NOT_EQ => {
                        _ = try self.emit(Opcode.OpNotEq, &[_]usize{});
                    },
                    INFIX_OP.GT => {
                        _ = try self.emit(Opcode.OpGT, &[_]usize{});
                    },
                    else => |other| {
                        stderr.print("Unknown operator {?}\n", .{other}) catch {};
                        return CompilerError.UnknownOperator;
                    },
                }
            },
            else => unreachable,
        }
    }

    fn parse_integer(self: *Compiler, int: ast.IntegerLiteral) CompilerError!void {
        const object = eval_utils.new_integer(self.alloc, int.value) catch return CompilerError.ObjectCreation;
        const identifier = try self.add_constant(object);

        // Cast to []usize
        const operands = &[_]usize{identifier};
        const pos = try self.emit(Opcode.OpConstant, operands);

        _ = pos;
    }

    pub fn get_bytecode(self: Compiler) Bytecode {
        return Bytecode{
            .instructions = self.instructions,
            .constants = self.constants,
        };
    }

    fn add_constant(self: *Compiler, object: *const Object) CompilerError!usize {
        try self.constants.append(object);

        // return the index, the constant identifier
        return self.constants.items.len - 1;
    }

    fn emit(self: *Compiler, opcode: Opcode, operands: []const usize) CompilerError!usize {
        const instruction = bytecode_.make(self.alloc, opcode, operands) catch return CompilerError.MakeInstr;
        const pos = try self.add_instruction(instruction);

        return pos;
    }

    fn add_instruction(self: *Compiler, instruction: []const u8) CompilerError!usize {
        // Starting position of the instruction
        const pos_new_instr = self.instructions.instructions.items.len;
        for (instruction) |b| {
            try self.instructions.instructions.append(b);
        }

        return pos_new_instr;
    }
};
