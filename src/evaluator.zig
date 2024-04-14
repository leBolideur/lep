const std = @import("std");

const ast = @import("ast.zig");
const obj_import = @import("object.zig");
const Object = obj_import.Object;

const eval_utils = @import("evaluator_utils.zig");
const EvalError = eval_utils.EvalError;

const Environment = @import("environment.zig").Environment;

const stderr = std.io.getStdOut().writer();

const INFIX_OP = enum { SUM, SUB, PRODUCT, DIVIDE, LT, GT, LTE, GTE, EQ, NOT_EQ };

pub const Evaluator = struct {
    infix_op_map: std.StringHashMap(INFIX_OP),
    env: *Environment,

    allocator: *const std.mem.Allocator,

    pub fn init(allocator: *const std.mem.Allocator, env: *Environment) !Evaluator {
        var infix_op_map = std.StringHashMap(INFIX_OP).init(allocator.*);
        try infix_op_map.put("+", INFIX_OP.SUM);
        try infix_op_map.put("-", INFIX_OP.SUB);
        try infix_op_map.put("*", INFIX_OP.PRODUCT);
        try infix_op_map.put("/", INFIX_OP.DIVIDE);
        try infix_op_map.put("<", INFIX_OP.LT);
        try infix_op_map.put(">", INFIX_OP.GT);
        try infix_op_map.put("<=", INFIX_OP.LTE);
        try infix_op_map.put(">=", INFIX_OP.GTE);
        try infix_op_map.put("==", INFIX_OP.EQ);
        try infix_op_map.put("!=", INFIX_OP.NOT_EQ);

        return Evaluator{
            .infix_op_map = infix_op_map,
            .env = env,
            .allocator = allocator,
        };
    }

    pub fn eval(self: Evaluator, node: ast.Node) EvalError!*const Object {
        switch (node) {
            .program => |p| return try self.eval_program(p),
            .statement => |s| return try self.eval_statement(s),
            .expression => |e| return try self.eval_expression(&e),
        }
    }

    fn eval_program(self: Evaluator, program: ast.Program) EvalError!*const Object {
        var result: *const Object = undefined;
        for (program.statements.items) |statement| {
            result = try self.eval_statement(statement);

            switch (result.*) {
                .ret => |ret| {
                    return ret.value;
                },
                .err => |err| {
                    stderr.print("\nError >> {s}", .{err.msg}) catch {};
                    return result;
                },
                else => {},
            }
        }

        return result;
    }

    fn eval_block(self: Evaluator, block: ast.BlockStatement) EvalError!*const Object {
        var result: *const Object = undefined;
        for (block.statements.items) |statement| {
            result = try self.eval_statement(statement);

            switch (result.*) {
                .ret => {
                    return result;
                },
                .err => |err| {
                    stderr.print("\nError >> {s}", .{err.msg}) catch {};
                    return result;
                },
                else => {},
            }
        }

        return result;
    }

    fn eval_expression(self: Evaluator, expression: *const ast.Expression) EvalError!*const Object {
        switch (expression.*) {
            .integer => |int| {
                const object = try eval_utils.new_integer(self.allocator, int.value);
                return object;
            },
            .boolean => |boo| {
                return eval_utils.new_boolean(boo.value);
            },
            .prefix_expr => |expr| {
                const right = try self.eval_expression(expr.right_expr);
                if (eval_utils.is_error(right)) return right;

                return try self.eval_prefix(expr.operator, right);
            },
            .infix_expr => |expr| {
                const right = try self.eval_expression(expr.right_expr);
                if (eval_utils.is_error(right)) return right;

                const left = try self.eval_expression(expr.left_expr);
                if (eval_utils.is_error(left)) return left;

                return try self.eval_infix(expr.operator, left, right);
            },
            .if_expression => |if_expr| {
                return try self.eval_if_expression(if_expr);
            },
            .identifier => |ident| {
                return try self.eval_identifier(ident);
            },
            else => unreachable,
        }
    }

    fn eval_if_expression(self: Evaluator, expr: ast.IfExpression) EvalError!*const Object {
        const condition = try self.eval_expression(expr.condition);
        if (eval_utils.is_error(condition)) return condition;

        switch (condition.*) {
            .boolean => |boo| {
                if (boo.value) {
                    return self.eval_block(expr.consequence);
                } else {
                    const alternative = expr.alternative orelse return eval_utils.new_null();
                    return self.eval_block(alternative);
                }
            },
            else => {
                return try eval_utils.new_error(
                    self.allocator,
                    "Condition of if/else must be a boolean, found {s} instead\n",
                    .{condition.*.typename()},
                );
            },
        }

        return eval_utils.new_null();
    }

    fn eval_identifier(self: Evaluator, ident: ast.Identifier) EvalError!*const Object {
        const val = self.env.get(ident.value) catch return EvalError.EnvGetError;
        return val orelse {
            return try eval_utils.new_error(
                self.allocator,
                "identifier not found: {s}",
                .{ident.value},
            );
        };
    }
    // fn eval_ret_statement(self: Evaluator, ret_statement: ast.RetStatement) EvalError!*const Object {
    //     const expr = try self.eval_expression(ret_statement.expression);
    //     const ret = eval_utils.new_return(self.allocator, expr);

    //     return ret;
    // }

    fn eval_statement(self: Evaluator, statement: ast.Statement) EvalError!*const Object {
        switch (statement) {
            .expr_statement => |expr_st| return try self.eval_expression(expr_st.expression),
            .ret_statement => |ret| {
                const expr = try self.eval_expression(ret.expression);
                if (eval_utils.is_error(expr)) return expr;

                return eval_utils.new_return(self.allocator, expr);
            },
            .block_statement => |block| return try self.eval_block(block),
            .var_statement => |va| {
                const expr = try self.eval_expression(va.expression);
                if (eval_utils.is_error(expr)) return expr;

                return self.env.set(va.name.value, expr) catch return EvalError.EnvSetError;
            },
        }
    }

    fn eval_prefix(self: Evaluator, op: u8, right: *const Object) EvalError!*const Object {
        switch (op) {
            '!' => return try self.eval_bang_op_expr(right),
            '-' => return try self.eval_minus_prefix_op_expr(right),
            else => {
                return try eval_utils.new_error(self.allocator, "unknown operator {c}{s}", .{ op, right.typename() });
            },
        }
    }

    fn eval_infix(
        self: Evaluator,
        op: []const u8,
        left: *const Object,
        right: *const Object,
    ) EvalError!*const Object {
        switch (left.*) {
            .integer => {
                switch (right.*) {
                    .integer => return self.eval_integer_infix(op, left, right),
                    else => {
                        return try eval_utils.new_error(
                            self.allocator,
                            "type mismatch: {s} {s} {s}",
                            .{ left.typename(), op, right.typename() },
                        );
                    },
                }
            },
            else => {
                return try eval_utils.new_error(
                    self.allocator,
                    "unknown operator: {s} {s} {s}",
                    .{ left.typename(), op, right.typename() },
                );
            },
        }
    }

    fn eval_integer_infix(
        self: Evaluator,
        op_: []const u8,
        left_: *const Object,
        right_: *const Object,
    ) EvalError!*const Object {
        const left = left_.integer.value;
        const right = right_.integer.value;

        const op = self.infix_op_map.get(op_) orelse {
            return try eval_utils.new_error(
                self.allocator,
                "unknown operator: {s} {s} {s}",
                .{ left_.typename(), op_, right_.typename() },
            );
        };

        switch (op) {
            INFIX_OP.SUM => {
                const object = try eval_utils.new_integer(self.allocator, left + right);
                return object;
            },
            INFIX_OP.SUB => {
                const object = try eval_utils.new_integer(self.allocator, left - right);
                return object;
            },
            INFIX_OP.PRODUCT => {
                const object = try eval_utils.new_integer(self.allocator, left * right);
                return object;
            },
            INFIX_OP.DIVIDE => {
                if (right == 0) {
                    return try eval_utils.new_error(self.allocator, "Impossible division by zero > {d} / 0", .{left});
                }
                const object = try eval_utils.new_integer(self.allocator, @divFloor(left, right));
                return object;
            },
            INFIX_OP.LT => {
                return eval_utils.new_boolean(left < right);
            },
            INFIX_OP.GT => {
                return eval_utils.new_boolean(left > right);
            },
            INFIX_OP.LTE => {
                return eval_utils.new_boolean(left <= right);
            },
            INFIX_OP.GTE => {
                return eval_utils.new_boolean(left >= right);
            },
            INFIX_OP.EQ => {
                return eval_utils.new_boolean(left == right);
            },
            INFIX_OP.NOT_EQ => {
                return eval_utils.new_boolean(left != right);
            },
        }
    }

    fn eval_bang_op_expr(self: Evaluator, right: *const Object) EvalError!*const Object {
        switch (right.*) {
            .boolean => |bo| {
                return eval_utils.new_boolean(!bo.value);
            },
            else => {
                return try eval_utils.new_error(self.allocator, "Bang operator must be use with Boolean only > {s}", .{right.typename()});
            },
        }
    }

    fn eval_minus_prefix_op_expr(self: Evaluator, right: *const Object) EvalError!*const Object {
        switch (right.*) {
            .integer => |int| {
                const object = try eval_utils.new_integer(self.allocator, -int.value);
                return object;
            },
            else => {
                return try eval_utils.new_error(self.allocator, "unknown operator: -{s}", .{right.typename()});
            },
        }
    }
};
