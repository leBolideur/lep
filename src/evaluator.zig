const std = @import("std");

const ast = @import("ast.zig");
const obj_import = @import("object.zig");
const Object = obj_import.Object;
const BuiltinObject = obj_import.BuiltinObject;

const eval_utils = @import("evaluator_utils.zig");
const EvalError = eval_utils.EvalError;

const Environment = @import("environment.zig").Environment;

const builtins = @import("builtins.zig");

const stderr = std.io.getStdOut().writer();

const INFIX_OP = enum { SUM, SUB, PRODUCT, DIVIDE, LT, GT, LTE, GTE, EQ, NOT_EQ };

pub const Evaluator = struct {
    infix_op_map: std.StringHashMap(INFIX_OP),
    builtins_map: std.StringHashMap(*const Object),

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

        var builtins_map = std.StringHashMap(*const Object).init(allocator.*);
        try builtins_map.put("len", try eval_utils.new_builtin(allocator, builtins.BuiltinFunction.len));

        return Evaluator{
            .infix_op_map = infix_op_map,
            .builtins_map = builtins_map,
            .allocator = allocator,
        };
    }

    pub fn eval(
        self: Evaluator,
        node: ast.Node,
        env: *Environment,
    ) EvalError!*const Object {
        switch (node) {
            .program => |p| return try self.eval_program(p, env),
            .statement => |s| return try self.eval_statement(s, env),
            .expression => |e| return try self.eval_expression(&e, env),
        }
    }

    fn eval_program(self: Evaluator, program: ast.Program, env: *Environment) EvalError!*const Object {
        var result: *const Object = undefined;
        for (program.statements.items) |statement| {
            result = try self.eval_statement(statement, env);

            switch (result.*) {
                .ret => |ret| {
                    return ret.value;
                },
                .err => |_| {
                    return result;
                },
                else => {},
            }
        }

        return result;
    }

    fn eval_block(
        self: Evaluator,
        block: ast.BlockStatement,
        env: *Environment,
    ) EvalError!*const Object {
        var result: *const Object = undefined;
        for (block.statements.items) |statement| {
            result = try self.eval_statement(statement, env);

            switch (result.*) {
                .ret => {
                    return result;
                },
                .err => |_| {
                    return result;
                },
                else => {},
            }
        }

        return result;
    }

    fn eval_expression(
        self: Evaluator,
        expression: *const ast.Expression,
        env: *Environment,
    ) EvalError!*const Object {
        switch (expression.*) {
            .integer => |int| {
                const object = try eval_utils.new_integer(self.allocator, int.value);
                return object;
            },
            .boolean => |boo| {
                return eval_utils.new_boolean(boo.value);
            },
            .string => |string| {
                return eval_utils.new_string(self.allocator, string.value);
            },
            .array => |array| {
                const elements = try self.eval_multiple_expr(&array.elements, env);
                return try eval_utils.new_array(self.allocator, elements);
            },
            .index_expr => |_| {
                unreachable;
            },
            .prefix_expr => |expr| {
                const right = try self.eval_expression(expr.right_expr, env);
                if (eval_utils.is_error(right)) return right;

                return try self.eval_prefix(expr.operator, right);
            },
            .infix_expr => |expr| {
                const right = try self.eval_expression(expr.right_expr, env);
                if (eval_utils.is_error(right)) return right;

                const left = try self.eval_expression(expr.left_expr, env);
                if (eval_utils.is_error(left)) return left;

                return try self.eval_infix(expr.operator, left, right);
            },
            .if_expression => |if_expr| {
                return try self.eval_if_expression(if_expr, env);
            },
            .identifier => |ident| {
                return try self.eval_identifier(ident, env);
            },
            .func => |func| {
                const fun = try eval_utils.new_func(self.allocator, env, func);
                // try env.add_fn(fun);
                switch (func) {
                    .named => |named| _ = env.add_var(named.name.value, fun) catch return EvalError.EnvAddError,
                    .literal => {},
                }

                // std.debug.print("eval_expr -- params >> {d}\n", .{func.parameters.items.len});
                return fun;
            },
            .call_expression => |call| {
                const func = try self.eval_expression(call.function, env);
                if (eval_utils.is_error(func)) return func;

                // std.debug.print("evaluator -- before args >> {d}\n", .{call.arguments.items.len});
                const args = try self.eval_multiple_expr(&call.arguments, env);
                // std.debug.print("evaluator -- args after >> {d}\n", .{args.items.len});

                return self.apply_function(func, args);
            },
        }
    }

    fn apply_function(
        self: Evaluator,
        object: *const Object,
        args: std.ArrayList(*const Object),
        // env: *Environment,
    ) EvalError!*const Object {
        var parameters: std.ArrayList(ast.Identifier) = undefined;
        var body: ast.BlockStatement = undefined;
        var env: *const Environment = undefined;
        switch (object.*) {
            .named_func => |f| {
                parameters = f.parameters;
                body = f.body;
                env = f.env;
            },
            .literal_func => |f| {
                parameters = f.parameters;
                body = f.body;
                env = f.env;
            },
            .builtin => |b| {
                return b.function.call(self.allocator, args);
            },
            else => |other| {
                return try eval_utils.new_error(
                    self.allocator,
                    "Cannot apply function with object type: {?}\n",
                    .{other},
                );
            },
        }

        if (args.items.len != parameters.items.len) {
            return try eval_utils.new_error(
                self.allocator,
                "Incorrect number of arguments > want: {d}, got: {d}\n",
                .{ parameters.items.len, args.items.len },
            );
        }

        var func_env = env.extend_env(args, parameters) catch return EvalError.EnvExtendError;
        const eval_body = try self.eval_block(body, func_env);

        // unwrap to void return bubbleup
        return switch (eval_body.*) {
            .ret => |ret| ret.value,
            else => eval_body,
        };
    }

    fn eval_multiple_expr(
        self: Evaluator,
        args: *const std.ArrayList(ast.Expression),
        env: *Environment,
    ) EvalError!std.ArrayList(*const Object) {
        var args_evaluated = std.ArrayList(*const Object).init(self.allocator.*);

        for (args.items) |arg| {
            const expression = try self.eval_expression(&arg, env);

            args_evaluated.append(expression) catch return EvalError.MemAlloc;
        }

        return args_evaluated;
    }

    fn eval_if_expression(
        self: Evaluator,
        expr: ast.IfExpression,
        env: *Environment,
    ) EvalError!*const Object {
        const condition = try self.eval_expression(expr.condition, env);
        if (eval_utils.is_error(condition)) return condition;

        switch (condition.*) {
            .boolean => |boo| {
                if (boo.value) {
                    return self.eval_block(expr.consequence, env);
                } else {
                    const alternative = expr.alternative orelse return eval_utils.new_null();
                    return self.eval_block(alternative, env);
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

    fn eval_identifier(self: Evaluator, ident: ast.Identifier, env: *Environment) EvalError!*const Object {
        const val = env.get_var(ident.value) catch return EvalError.EnvGetError;
        if (val == null) {
            const builtin = self.builtins_map.get(ident.value);
            if (builtin != null) {
                return builtin.?;
            }
        } else {
            return val.?;
        }

        return try eval_utils.new_error(
            self.allocator,
            "identifier not found: {s}",
            .{ident.value},
        );
    }

    fn eval_statement(self: Evaluator, statement: ast.Statement, env: *Environment) EvalError!*const Object {
        switch (statement) {
            .expr_statement => |expr_st| return try self.eval_expression(expr_st.expression, env),
            .ret_statement => |ret| {
                const expr = try self.eval_expression(ret.expression, env);
                if (eval_utils.is_error(expr)) return expr;

                return eval_utils.new_return(self.allocator, expr);
            },
            .block_statement => |block| return try self.eval_block(block, env),
            .var_statement => |va| {
                const expr = try self.eval_expression(va.expression, env);
                if (eval_utils.is_error(expr)) return expr;

                return env.add_var(va.name.value, expr) catch return EvalError.EnvAddError;
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
            .string => {
                switch (right.*) {
                    .string => return self.eval_string_infix(op, left, right),
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

    fn eval_string_infix(
        self: Evaluator,
        op_: []const u8,
        left_: *const Object,
        right_: *const Object,
    ) EvalError!*const Object {
        const left = left_.string.value;
        const right = right_.string.value;

        const op = self.infix_op_map.get(op_) orelse {
            return try eval_utils.new_error(
                self.allocator,
                "unknown operator: {s} {s} {s}",
                .{ left_.typename(), op_, right_.typename() },
            );
        };

        switch (op) {
            INFIX_OP.SUM => {
                const left_len = left.len;
                const right_len = right.len;
                const total = left_len + right_len;

                var buf = self.allocator.alloc(u8, total) catch return EvalError.MemAlloc;
                std.mem.copy(u8, buf[0..left_len], left);
                std.mem.copy(u8, buf[left_len..total], right);

                // Be careful with 'buf' in case of allocator type change
                const object = try eval_utils.new_string(self.allocator, buf);
                return object;
            },
            else => {
                return try eval_utils.new_error(
                    self.allocator,
                    "unknown operator: {s} {s} {s}",
                    .{ left_.typename(), op_, right_.typename() },
                );
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
