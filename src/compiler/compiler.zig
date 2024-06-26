const std = @import("std");

const common = @import("common");
const builtins = common.builtins;

const ast = common.ast;
const object_import = common.object;
const Object = object_import.Object;

const bytecode_ = @import("bytecode.zig");

const Opcode = @import("opcode.zig").Opcode;

const sym_import = @import("symbol_table.zig");
const SymbolTable = sym_import.SymbolTable;
const SymbolScope = sym_import.SymbolScope;
const SymbolError = sym_import.SymbolTableError;
const SymbolType = sym_import.SymbolType;

const eval_utils = common.eval_utils;

const Token = @import("interpreter").token.Token;

const INFIX_OP = enum { SUM, SUB, MUL, DIV, LT, GT, LTE, GTE, EQ, NOT_EQ };

const CompilerError = error{
    OutOfMemory,
    ObjectCreation,
    MakeInstr,
    UnknownOperator,
    SetSymbol,
    GetSymbol,
    UndefinedVariable,
    SortError,
    EnterScope,
    InvalidPosition,
    MemAlloc,
    SymbolTable,
    DefineParams,
    DefineBuiltin,
    NewError,
    AddToErrorList,
};

pub const Bytecode = struct {
    instructions: std.ArrayList(u8),
    constants: std.ArrayList(*const Object),
};

const EmittedInstruction = struct {
    opcode: Opcode,
    position: usize,
};

const Scope = struct {
    instructions: std.ArrayList(u8),
    last_instruction: ?EmittedInstruction,
    previous_instruction: ?EmittedInstruction,
};

const CompError = struct {
    line: usize,
    col: usize,
    msg: []const u8,
};

const stderr = std.io.getStdErr().writer();

pub const Compiler = struct {
    constants: std.ArrayList(*const Object),

    scopes: std.ArrayList(Scope),
    scope_index: usize,

    symbol_table: *SymbolTable,

    infix_op_map: std.StringHashMap(INFIX_OP),

    errors_list: std.ArrayList(CompError),

    alloc: *const std.mem.Allocator,

    pub fn init_with_state(alloc: *const std.mem.Allocator, symtab: *SymbolTable, constants: std.ArrayList(*const Object)) CompilerError!Compiler {
        var c = try Compiler.init(alloc);
        c.symbol_table = symtab;
        c.constants = constants;
        return c;
    }

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

        const main_scope = Scope{
            .instructions = std.ArrayList(u8).init(alloc.*),
            .previous_instruction = null,
            .last_instruction = null,
        };
        var scopes = std.ArrayList(Scope).init(alloc.*);
        try scopes.append(main_scope);

        const symtab = SymbolTable.new(alloc) catch return CompilerError.MemAlloc;
        for (builtins.builtins, 0..) |builtin, index| {
            _ = symtab.define_builtin(index, builtin.name) catch return CompilerError.DefineBuiltin;
        }

        return Compiler{
            .constants = constants,

            .scopes = scopes,
            .scope_index = 0,

            .symbol_table = symtab,

            .infix_op_map = infix_op_map,

            .errors_list = std.ArrayList(CompError).init(alloc.*),

            .alloc = alloc,
        };
    }

    fn current_scope(self: *Compiler) *Scope {
        return &self.scopes.items[self.scope_index];
    }

    pub fn enter_scope(self: *Compiler) !void {
        const new = Scope{
            .instructions = std.ArrayList(u8).init(self.alloc.*),
            .last_instruction = null,
            .previous_instruction = null,
        };

        try self.scopes.append(new);
        self.scope_index += 1;

        self.symbol_table = SymbolTable.new_enclosed(self.alloc, self.symbol_table) catch return CompilerError.MemAlloc;
    }

    fn check_unused_identifier(self: *Compiler) CompilerError!void {
        var iter = self.symbol_table.store.iterator();
        while (iter.next()) |item| {
            const value = item.value_ptr.*;

            if (!value.used and value.scope != SymbolScope.BUILTIN and value.sym_type != SymbolType.FUNC) {
                try self.new_comp_error(value.token, "Variable '{s}' is never used", .{value.name});
            }
        }
    }

    pub fn leave_scope(self: *Compiler) CompilerError!std.ArrayList(u8) {
        try self.check_unused_identifier();

        const instructions = self.current_scope().instructions;
        _ = self.scopes.pop();
        self.scope_index -= 1;

        self.symbol_table = self.symbol_table.outer orelse return CompilerError.SymbolTable;

        return instructions;
    }

    fn new_comp_error(
        self: *Compiler,
        token: Token,
        comptime fmt: []const u8,
        args: anytype,
    ) CompilerError!void {
        const fmt_msg = std.fmt.allocPrint(self.alloc.*, fmt, args) catch return CompilerError.MemAlloc;
        var msg = fmt_msg;
        msg = std.fmt.allocPrint(
            self.alloc.*,
            "line: {d} at col: {d}\t{s}",
            .{ token.line, token.col, fmt_msg },
        ) catch return CompilerError.MemAlloc;

        const err = CompError{
            .line = token.line,
            .col = token.col,
            .msg = msg,
        };

        self.errors_list.append(err) catch return CompilerError.AddToErrorList;
    }

    pub fn has_errors(self: Compiler) bool {
        return self.errors_list.items.len > 0;
    }

    pub fn compile(self: *Compiler, node: ast.Node) CompilerError!void {
        switch (node) {
            .program => |program| {
                for (program.statements.items) |st| {
                    try self.compile_statement(st);
                }
            },
            else => unreachable,
        }

        // Check the global symtab
        try self.check_unused_identifier();
    }

    fn compile_statement(self: *Compiler, st: ast.Statement) CompilerError!void {
        switch (st) {
            .var_statement => |var_st| {
                const symbol = self.symbol_table.define(var_st.name.value, var_st.token, SymbolType.VAR) catch |e| {
                    if (e == SymbolError.AlreadyDeclared) {
                        try self.new_comp_error(var_st.token, "Variable '{s}' is already declared.", .{var_st.name.value});
                    }
                    return;
                };
                try self.compile_expression(var_st.expression);

                if (symbol.scope == SymbolScope.GLOBAL) {
                    _ = try self.emit(Opcode.OpSetGlobal, &[_]usize{symbol.index});
                } else {
                    _ = try self.emit(Opcode.OpSetLocal, &[_]usize{symbol.index});
                }
            },
            .ret_statement => |ret_st| {
                try self.compile_expression(ret_st.expression);
                _ = try self.emit(Opcode.OpReturnValue, &[_]usize{});
            },
            .expr_statement => |expr_st| {
                try self.compile_expression(expr_st.expression);
                _ = try self.emit(Opcode.OpPop, &[_]usize{});
            },
            .block_statement => |block| {
                for (block.statements.items) |b_st| {
                    try self.compile_statement(b_st);
                }
            },
        }
    }

    // FIXME: Ugly and duplicate...
    fn compile_block_statement(self: *Compiler, block: ast.BlockStatement) CompilerError!void {
        for (block.statements.items) |b_st| {
            try self.compile_statement(b_st);
        }
    }

    fn compile_expression(self: *Compiler, expr: *const ast.Expression) CompilerError!void {
        switch (expr.*) {
            .integer => |int| {
                try self.compile_integer(int);
            },
            .boolean => |boo| {
                if (boo.value) {
                    _ = try self.emit(Opcode.OpTrue, &[_]usize{});
                } else {
                    _ = try self.emit(Opcode.OpFalse, &[_]usize{});
                }
            },
            .identifier => |ident| {
                const symbol = self.symbol_table.resolve(ident.value);
                if (symbol == null) {
                    try self.new_comp_error(ident.token, "Undefined variable '{s}'", .{ident.value});
                    return;
                }

                if (symbol.?.scope == SymbolScope.GLOBAL) {
                    _ = try self.emit(Opcode.OpGetGlobal, &[_]usize{symbol.?.index});
                } else if (symbol.?.scope == SymbolScope.LOCAL) {
                    _ = try self.emit(Opcode.OpGetLocal, &[_]usize{symbol.?.index});
                } else {
                    _ = try self.emit(Opcode.OpGetBuiltin, &[_]usize{symbol.?.index});
                }
            },
            .string => |string| {
                const str_obj = eval_utils.new_string(self.alloc, string.value) catch return CompilerError.ObjectCreation;
                const const_index = try self.add_constant(str_obj);
                _ = try self.emit(Opcode.OpConstant, &[_]usize{const_index});
            },
            .array => |array| {
                for (array.elements.items) |elem| {
                    try self.compile_expression(&elem);
                }

                _ = try self.emit(Opcode.OpArray, &[_]usize{array.elements.items.len});
            },
            .hash => |hash| {
                const sorted = try self.sort_hash(hash.pairs);
                for (sorted) |key| {
                    // Have to push strings key object
                    const key_obj = eval_utils.new_string(self.alloc, key) catch return CompilerError.ObjectCreation;
                    const const_index = try self.add_constant(key_obj);
                    _ = try self.emit(Opcode.OpConstant, &[_]usize{const_index});

                    const value = hash.pairs.get(key);
                    try self.compile_expression(&value.?);
                }

                _ = try self.emit(Opcode.OpHash, &[_]usize{hash.pairs.count() * 2}); // *2 -> pair = key and value
            },
            .index_expr => |index| {
                try self.compile_expression(index.left);
                try self.compile_expression(index.index);
                _ = try self.emit(Opcode.OpIndex, &[_]usize{});
            },
            .prefix_expr => |prefix| {
                try self.compile_expression(prefix.right_expr);

                switch (prefix.operator) {
                    '-' => _ = try self.emit(Opcode.OpMinus, &[_]usize{}),
                    '!' => _ = try self.emit(Opcode.OpBang, &[_]usize{}),
                    else => |other| {
                        try self.new_comp_error(prefix.token, "Unknown Prefix operator {?}\n", .{other});
                        return;
                    },
                }
            },
            .infix_expr => |infix| {
                const op_ = infix.operator;
                const op = self.infix_op_map.get(op_);
                // Reordering for < operator
                if (op == INFIX_OP.LT) {
                    // FIRST compile right THEN left (inverse order of push on stack)
                    try self.compile_expression(infix.right_expr);
                    try self.compile_expression(infix.left_expr);

                    _ = try self.emit(Opcode.OpGT, &[_]usize{});

                    return;
                }

                // Normal order, left then right
                try self.compile_expression(infix.left_expr);
                try self.compile_expression(infix.right_expr);

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
                        try self.new_comp_error(infix.token, "Unknown Infix operator {?}\n", .{other});
                        return;
                    },
                }
            },
            .if_expression => |if_expr| {
                try self.compile_expression(if_expr.condition);

                const jump_not_true_pos = try self.emit(Opcode.OpJumpNotTrue, &[_]usize{9999});

                for (if_expr.consequence.statements.items) |b_st| {
                    try self.compile_statement(b_st);
                }

                if (self.last_instruction_is(Opcode.OpPop))
                    self.remove_last_pop();

                const jump_pos = try self.emit(Opcode.OpJump, &[_]usize{9999});
                const after_consequence = self.current_scope().instructions.items.len;
                try self.change_operand(jump_not_true_pos, &[_]usize{after_consequence});

                if (if_expr.alternative == null) {
                    _ = try self.emit(Opcode.OpNull, &[_]usize{});
                } else {
                    for (if_expr.alternative.?.statements.items) |b_st| {
                        try self.compile_statement(b_st);
                    }

                    if (self.last_instruction_is(Opcode.OpPop))
                        self.remove_last_pop();
                }

                const after_alternative = self.current_scope().instructions.items.len;
                try self.change_operand(jump_pos, &[_]usize{after_alternative});
            },
            .func => |func| {
                switch (func) {
                    .literal => |lit| {
                        try self.compile_function(lit);
                    },
                    .named => |named| {
                        const lit = named.func_literal.*;

                        const symbol = self.symbol_table.define(named.name.value, lit.token, SymbolType.FUNC) catch return CompilerError.SetSymbol;
                        try self.compile_function(lit);

                        if (symbol.scope == SymbolScope.GLOBAL) {
                            _ = try self.emit(Opcode.OpSetGlobal, &[_]usize{symbol.index});
                        } else {
                            _ = try self.emit(Opcode.OpSetLocal, &[_]usize{symbol.index});
                        }
                    },
                }
            },
            .call_expression => |call| {
                try self.compile_expression(call.function);

                for (call.arguments.items) |arg| {
                    try self.compile_expression(&arg);
                }
                const args_len = call.arguments.items.len;

                _ = try self.emit(Opcode.OpCall, &[_]usize{args_len});
            },
        }
    }

    fn compile_function(self: *Compiler, lit: ast.FunctionLiteral) !void {
        self.enter_scope() catch return CompilerError.EnterScope;

        for (lit.parameters.items) |param| {
            _ = self.symbol_table.define(param.value, param.token, SymbolType.VAR) catch return CompilerError.DefineParams;
        }

        try self.compile_block_statement(lit.body);

        // Implicit return
        if (self.last_instruction_is(Opcode.OpPop)) {
            try self.replace_last_pop_with_return();
        }
        // function with empty body
        if (!self.last_instruction_is(Opcode.OpReturnValue)) {
            _ = try self.emit(Opcode.OpReturn, &[_]usize{});
        }

        const locals_count = self.symbol_table.definitions_count;

        const instructions = try self.leave_scope();

        const func_obj = eval_utils.new_compiled_func(self.alloc, instructions, locals_count, lit.parameters.items.len) catch return CompilerError.ObjectCreation;
        const constant_idx = try self.add_constant(func_obj);

        _ = try self.emit(Opcode.OpConstant, &[_]usize{constant_idx});
    }

    fn replace_last_pop_with_return(self: *Compiler) !void {
        var current = self.current_scope();
        const last_position = current.last_instruction.?.position;

        const op_return = bytecode_.make(self.alloc, Opcode.OpReturnValue, &[_]usize{}) catch return CompilerError.MakeInstr;
        self.replace_instruction(last_position, op_return);

        current.last_instruction.?.opcode = Opcode.OpReturnValue;
    }

    fn compare_strings(_: void, lhs: []const u8, rhs: []const u8) bool {
        return std.mem.order(u8, lhs, rhs).compare(std.math.CompareOperator.lt);
    }

    fn sort_hash(
        self: *Compiler,
        pairs: std.StringHashMap(ast.Expression),
    ) CompilerError![]const []const u8 {
        var to_sort = std.ArrayList([]const u8).init(self.alloc.*);
        var iterator_sort = pairs.iterator();
        while (iterator_sort.next()) |item| {
            const key = item.key_ptr.*;
            try to_sort.append(key);
        }
        const sorted = to_sort.toOwnedSlice() catch return CompilerError.SortError;
        std.sort.insertion([]const u8, sorted, {}, compare_strings);
        return sorted;
    }

    fn compile_integer(self: *Compiler, int: ast.IntegerLiteral) CompilerError!void {
        const object = eval_utils.new_integer(self.alloc, int.value) catch return CompilerError.ObjectCreation;
        const identifier = try self.add_constant(object);

        _ = try self.emit(Opcode.OpConstant, &[_]usize{identifier});
    }

    pub fn get_bytecode(self: *Compiler) Bytecode {
        return Bytecode{
            .instructions = self.current_scope().instructions,
            .constants = self.constants,
        };
    }

    fn add_constant(self: *Compiler, object: *const Object) CompilerError!usize {
        try self.constants.append(object);

        // return the index, the constant identifier
        return self.constants.items.len - 1;
    }

    pub fn emit(self: *Compiler, opcode: Opcode, operands: []const usize) CompilerError!usize {
        const instruction = bytecode_.make(self.alloc, opcode, operands) catch return CompilerError.MakeInstr;
        const pos = try self.add_instruction(instruction);

        var current = self.current_scope();
        current.previous_instruction = current.last_instruction;
        current.last_instruction = EmittedInstruction{ .opcode = opcode, .position = pos };

        return pos;
    }

    fn add_instruction(self: *Compiler, instruction: []const u8) CompilerError!usize {
        var current = self.current_scope();
        // Starting position of the instruction
        const pos_new_instr = current.instructions.items.len;
        for (instruction) |b| {
            try current.instructions.append(b);
        }

        return pos_new_instr;
    }

    fn last_instruction_is(self: *Compiler, opcode: Opcode) bool {
        const current = self.current_scope();
        if (current.instructions.items.len == 0) return false; // function with no body?

        const last = current.last_instruction orelse return false;
        return last.opcode == opcode;
    }

    fn remove_last_pop(self: *Compiler) void {
        var current = self.current_scope();
        _ = current.instructions.pop();
        current.last_instruction = current.previous_instruction;
    }

    fn replace_instruction(self: *Compiler, pos: usize, new: []const u8) void {
        var current = self.current_scope();
        var i: usize = 0;
        while (i < new.len) : (i += 1) {
            current.instructions.items[pos + i] = new[i];
        }
    }

    fn change_operand(self: *Compiler, pos: usize, operand: []const usize) CompilerError!void {
        const current = self.current_scope();

        const opcode = @as(Opcode, @enumFromInt(current.instructions.items[pos]));
        const new_instruction = bytecode_.make(self.alloc, opcode, operand) catch return CompilerError.MakeInstr;
        self.replace_instruction(pos, new_instruction);
    }
};
