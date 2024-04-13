const std = @import("std");

const ast = @import("ast.zig");
const obj_import = @import("object.zig");
const Object = obj_import.Object;
const Integer = obj_import.Integer;
const Null = obj_import.Null;
const Boolean = obj_import.Boolean;
const ObjectType = obj_import.ObjectType;

const EvalError = error{BadNode};

const stderr = std.io.getStdOut().writer();

const TRUE = Object{
    .boolean = Boolean{
        .type = ObjectType.Boolean,
        .value = true,
    },
};
const FALSE = Object{
    .boolean = Boolean{
        .type = ObjectType.Boolean,
        .value = false,
    },
};
const NULL = Object{
    .null = Null{
        .type = ObjectType.Null,
    },
};

const INFIX_OP = enum { SUM, SUB, PRODUCT, DIVIDE, LT, GT, LTE, GTE, EQ, NOT_EQ };

pub const Evaluator = struct {
    infix_op_map: std.StringHashMap(INFIX_OP),

    // allocator: *const std.mem.Allocator,
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
        };
    }

    pub fn eval(self: Evaluator, node: ast.Node) EvalError!Object {
        switch (node) {
            .program => |p| return try self.eval_program(p),
            .statement => |s| return try self.eval_statement(s),
            .expression => |e| return try self.eval_expression(&e),
        }
    }

    fn eval_program(self: Evaluator, program: ast.Program) EvalError!Object {
        var result: Object = undefined;
        for (program.statements.items) |statement| {
            result = try self.eval_statement(statement);
        }

        return result;
    }

    fn eval_block(self: Evaluator, block: ast.BlockStatement) EvalError!Object {
        var result: Object = undefined;
        for (block.statements.items) |statement| {
            result = try self.eval_statement(statement);
        }

        return result;
    }

    fn eval_expression(self: Evaluator, expression: *const ast.Expression) EvalError!Object {
        switch (expression.*) {
            .integer => |int| {
                return Object{
                    .integer = Integer{
                        .type = ObjectType.Integer,
                        .value = int.value,
                    },
                };
            },
            .boolean => |boo| {
                return self.get_boolean(boo.value);
            },
            .prefix_expr => |expr| {
                const node = ast.Node{ .expression = expr.right_expr.* };
                const right = try self.eval(node);

                return try self.eval_prefix(expr.operator, right);
            },
            .infix_expr => |expr| {
                const node_right = ast.Node{ .expression = expr.right_expr.* };
                const right = try self.eval(node_right);

                const node_left = ast.Node{ .expression = expr.left_expr.* };
                const left = try self.eval(node_left);

                return try self.eval_infix(expr.operator, left, right);
            },
            .block_statement => |block| {
                return try self.eval_block(block);
            },
            .if_expression => |if_expr| {
                return try self.eval_if_expression(&if_expr);
            },
            else => unreachable,
        }
    }

    fn eval_if_expression(self: Evaluator, expr: *const ast.IfExpression) EvalError!Object {
        const condition = try self.eval_expression(expr.*.condition);

        switch (condition) {
            .boolean => {},
            else => stderr.print("Condition of if/else must be a boolean\n", .{}) catch {},
        }

        if (condition.boolean.value) {
            return self.eval_block(expr.*.consequence);
        } else {
            const alternative = expr.*.alternative orelse return NULL;
            return self.eval_block(alternative);
        }

        return NULL;
    }

    fn eval_statement(self: Evaluator, statement: ast.Statement) EvalError!Object {
        switch (statement) {
            .expr_statement => |expr_st| return try self.eval_expression(expr_st.expression),
            else => return Object{ .null = Null{ .type = ObjectType.Null } },
        }
    }

    fn eval_prefix(self: Evaluator, op: u8, right: Object) EvalError!Object {
        switch (op) {
            '!' => return try self.eval_bang_op_expr(right),
            '-' => return try self.eval_minus_prefix_op_expr(right),
            else => {
                stderr.print("Unknown prefix operator\n", .{}) catch {};
                return NULL;
            },
        }
    }

    fn eval_infix(self: Evaluator, op: []const u8, left: Object, right: Object) EvalError!Object {
        const left_type = @tagName(left);
        const right_type = @tagName(right);

        if (!std.mem.eql(u8, left_type, right_type)) {
            stderr.print("All operands must have the same type\n", .{}) catch {};
            return NULL;
        }

        // At this point left and right has the same type
        switch (left) {
            .integer => return self.eval_integer_infix(op, left, right),
            else => unreachable,
        }

        return NULL;
    }

    fn eval_integer_infix(self: Evaluator, op_: []const u8, left_: Object, right_: Object) EvalError!Object {
        const left = left_.integer.value;
        const right = right_.integer.value;
        const op = self.infix_op_map.get(op_);
        // std.debug.print("{d} {?} {d} >> {s}\n", .{ left, op, right, op_ });

        switch (op.?) {
            INFIX_OP.SUM => {
                const result = Integer{ .type = ObjectType.Integer, .value = left + right };
                return Object{ .integer = result };
            },
            INFIX_OP.SUB => {
                const result = Integer{ .type = ObjectType.Integer, .value = left - right };
                return Object{ .integer = result };
            },
            INFIX_OP.PRODUCT => {
                const result = Integer{ .type = ObjectType.Integer, .value = left * right };
                return Object{ .integer = result };
            },
            INFIX_OP.DIVIDE => {
                if (right == 0) {
                    stderr.print("Impossible divide by zero\n", .{}) catch {};
                    return NULL;
                }
                const result = Integer{ .type = ObjectType.Integer, .value = @divFloor(left, right) };
                return Object{ .integer = result };
            },
            INFIX_OP.LT => {
                return self.get_boolean(left < right);
            },
            INFIX_OP.GT => {
                return self.get_boolean(left > right);
            },
            INFIX_OP.LTE => {
                return self.get_boolean(left <= right);
            },
            INFIX_OP.GTE => {
                return self.get_boolean(left >= right);
            },
            INFIX_OP.EQ => {
                return self.get_boolean(left == right);
            },
            INFIX_OP.NOT_EQ => {
                return self.get_boolean(left != right);
            },

            // else => {
            //     stderr.print("Unknown operator\n", .{}) catch {};
            //     return NULL;
            // },
        }
    }

    fn eval_bang_op_expr(self: Evaluator, right: Object) EvalError!Object {
        switch (right) {
            .boolean => |bo| {
                return self.get_boolean(!bo.value);
            },
            else => {
                stderr.print("Bang operator must be use with Boolean only\n", .{}) catch {};
                return NULL;
            },
        }
    }

    fn eval_minus_prefix_op_expr(self: Evaluator, right: Object) EvalError!Object {
        _ = self;
        switch (right) {
            .integer => |int| {
                const integer = Integer{ .type = ObjectType.Integer, .value = -int.value };
                return Object{ .integer = integer };
            },

            else => {
                stderr.print("Minus operator must be use with Integers only\n", .{}) catch {};
                return NULL;
            },
        }
    }

    fn get_boolean(_: Evaluator, value: bool) Object {
        // Is this really return the reference ?
        if (value) return TRUE;
        return FALSE;
    }
};
