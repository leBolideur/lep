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

pub const Evaluator = struct {
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
                // Is this really return the reference ?
                return self.get_boolean(boo.value);
            },
            .prefix_expr => |expr| {
                const node = ast.Node{ .expression = expr.right_expr.* };
                const right = try self.eval(node);
                return try self.eval_prefix(expr.operator, right);
            },
            else => unreachable,
        }
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

    fn eval_bang_op_expr(self: Evaluator, right: Object) EvalError!Object {
        _ = self;
        switch (right) {
            .boolean => |bo| {
                if (bo.value == true) return FALSE;
                return TRUE;
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
        if (value) return TRUE;
        return FALSE;
    }
};
