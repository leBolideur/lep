const std = @import("std");

const ast = @import("ast.zig");
const obj_import = @import("object.zig");
const Object = obj_import.Object;

const eval_utils = @import("evaluator_utils.zig");
const EvalError = eval_utils.EvalError;

const stderr = std.io.getStdOut().writer();

const INFIX_OP = enum { SUM, SUB, PRODUCT, DIVIDE, LT, GT, LTE, GTE, EQ, NOT_EQ };

pub const Evaluator = struct {
    infix_op_map: std.StringHashMap(INFIX_OP),

    allocator: *const std.mem.Allocator,
    pub fn init(allocator: *const std.mem.Allocator) !Evaluator {
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

                return try self.eval_prefix(expr.operator, right);
            },
            .infix_expr => |expr| {
                const right = try self.eval_expression(expr.right_expr);
                const left = try self.eval_expression(expr.left_expr);

                return try self.eval_infix(expr.operator, left, right);
            },
            .if_expression => |if_expr| {
                return try self.eval_if_expression(if_expr);
            },
            else => unreachable,
        }
    }

    fn eval_if_expression(self: Evaluator, expr: ast.IfExpression) EvalError!*const Object {
        const condition = try self.eval_expression(expr.condition);

        switch (condition.*) {
            .boolean => |boo| {
                if (boo.value) {
                    return self.eval_block(expr.consequence);
                } else {
                    const alternative = expr.alternative orelse return eval_utils.new_null();
                    return self.eval_block(alternative);
                }
            },
            else => stderr.print("Condition of if/else must be a boolean\n", .{}) catch {},
        }

        return eval_utils.new_null();
    }

    fn eval_ret_statement(self: Evaluator, ret_statement: ast.RetStatement) EvalError!*const Object {
        const expr = try self.eval_expression(ret_statement.expression);
        const ret = eval_utils.new_return(self.allocator, expr);

        return ret;
    }

    fn eval_statement(self: Evaluator, statement: ast.Statement) EvalError!*const Object {
        switch (statement) {
            .expr_statement => |expr_st| return try self.eval_expression(expr_st.expression),
            .ret_statement => |ret| return try self.eval_ret_statement(ret),
            .block_statement => |block| return try self.eval_block(block),
            else => return eval_utils.new_null(),
        }
    }

    fn eval_prefix(self: Evaluator, op: u8, right: *const Object) EvalError!*const Object {
        switch (op) {
            '!' => return try self.eval_bang_op_expr(right),
            '-' => return try self.eval_minus_prefix_op_expr(right),
            else => {
                stderr.print("Unknown prefix operator\n", .{}) catch {};
                return eval_utils.new_null();
            },
        }
    }

    fn eval_infix(
        self: Evaluator,
        op: []const u8,
        left: *const Object,
        right: *const Object,
    ) EvalError!*const Object {
        const left_type = @tagName(left.*);
        const right_type = @tagName(right.*);

        if (!std.mem.eql(u8, left_type, right_type)) {
            stderr.print("All operands must have the same type\n", .{}) catch {};
            return eval_utils.new_null();
        }

        // At this point left and right has the same type
        switch (left.*) {
            .integer => return self.eval_integer_infix(op, left, right),
            else => unreachable,
        }

        return eval_utils.new_null();
    }

    fn eval_integer_infix(
        self: Evaluator,
        op_: []const u8,
        left_: *const Object,
        right_: *const Object,
    ) EvalError!*const Object {
        const left = left_.integer.value;
        const right = right_.integer.value;
        const op = self.infix_op_map.get(op_);
        // std.debug.print("{d} {?} {d} >> {s}\n", .{ left, op, right, op_ });

        switch (op.?) {
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
                    stderr.print("Impossible divide by zero\n", .{}) catch {};
                    return eval_utils.new_null();
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

    fn eval_bang_op_expr(_: Evaluator, right: *const Object) EvalError!*const Object {
        switch (right.*) {
            .boolean => |bo| {
                return eval_utils.new_boolean(!bo.value);
            },
            else => {
                stderr.print("Bang operator must be use with Boolean only\n", .{}) catch {};
                return eval_utils.new_null();
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
                stderr.print("Minus operator must be use with Integers only\n", .{}) catch {};
                return eval_utils.new_null();
            },
        }
    }
};
