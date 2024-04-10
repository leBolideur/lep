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

    pub fn eval_expression(self: Evaluator, expression: *const ast.Expression) EvalError!Object {
        _ = self;
        switch (expression.*) {
            .integer => |int| {
                return Object{
                    .integer = Integer{
                        .type = ObjectType.Integer,
                        .value = int.value,
                    },
                };
            },
            else => unreachable,
        }
    }

    pub fn eval_statement(self: Evaluator, statement: ast.Statement) EvalError!Object {
        switch (statement) {
            .expr_statement => |expr_st| return try self.eval_expression(expr_st.expression),
            else => return Object{ .null = Null{ .type = ObjectType.Null } },
        }
    }
};
