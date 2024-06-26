const std = @import("std");

const interpreter = @import("interpreter");
const common = @import("common");

const token = interpreter.token;
const Token = token.Token;
const TokenType = token.TokenType;

const DebugError = anyerror || error{DebugString};

pub const Node = union(enum) {
    program: Program,
    statement: Statement,
    expression: Expression,
    err: []const u8,

    pub fn debug_string(self: Node, buf: *std.ArrayList(u8)) DebugError![]const u8 {
        switch (self) {
            .program => |prog| try prog.debug_string(buf),
            .statement => |st| try st.debug_string(buf),
            .expression => |expr| try expr.debug_string(buf),
            .err => {},
        }

        return buf.toOwnedSlice();
    }
};

pub const Statement = union(enum) {
    var_statement: VarStatement,
    ret_statement: RetStatement,
    expr_statement: ExprStatement,
    block_statement: BlockStatement,

    pub fn debug_string(self: Statement, buf: *std.ArrayList(u8)) DebugError!void {
        try switch (self) {
            .var_statement => |vs| vs.debug_string(buf),
            .ret_statement => |rs| rs.debug_string(buf),
            .expr_statement => |es| es.debug_string(buf),
            .block_statement => |block| block.debug_string(buf),
        };
    }
};

pub const Function = union(enum) {
    named: NamedFunction,
    literal: FunctionLiteral,

    pub fn debug_string(self: *const Function, buf: *std.ArrayList(u8)) DebugError!void {
        try switch (self.*) {
            .named => |func| func.debug_string(buf),
            .literal => |func| func.debug_string(buf),
        };
    }
};

pub const Expression = union(enum) {
    // Identifier can be an expression (use of binding) and a statement (binding)
    identifier: Identifier,
    integer: IntegerLiteral,
    boolean: Boolean,
    string: StringLiteral,
    array: ArrayLiteral,
    hash: HashLiteral,
    index_expr: IndexExpression,
    prefix_expr: PrefixExpr,
    infix_expr: InfixExpr,
    if_expression: IfExpression,
    func: Function,
    call_expression: CallExpression,

    pub fn debug_string(self: *const Expression, buf: *std.ArrayList(u8)) DebugError!void {
        try switch (self.*) {
            .identifier => |id| id.debug_string(buf),
            .integer => |int| int.debug_string(buf),
            .boolean => |bo| bo.debug_string(buf),
            .string => |str| str.debug_string(buf),
            .array => |arr| arr.debug_string(buf),
            .hash => |hash| hash.debug_string(buf),
            .index_expr => |idx| idx.debug_string(buf),
            .prefix_expr => |prf| prf.debug_string(buf),
            .infix_expr => |inf| inf.debug_string(buf),
            .if_expression => |ife| ife.debug_string(buf),
            .func => |f| f.debug_string(buf),
            .call_expression => |call| call.debug_string(buf),
        };
    }
};

pub const Program = struct {
    statements: std.ArrayList(Statement),

    pub fn init(allocator: *const std.mem.Allocator) Program {
        return Program{
            .statements = std.ArrayList(Statement).init(allocator.*),
        };
    }

    pub fn token_literal(self: Program) []const u8 {
        if (self.statements.len > 0)
            return self.statements[0].token_literal();
        return "";
    }

    pub fn debug_string(self: Program, buf: *std.ArrayList(u8)) DebugError!void {
        for (self.statements.items) |st| {
            st.debug_string(buf) catch return DebugError.DebugString;
        }
    }
};

pub const VarStatement = struct {
    token: Token,
    name: Identifier,
    expression: *const Expression,

    pub fn token_literal(self: VarStatement) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: VarStatement, buf: *std.ArrayList(u8)) DebugError!void {
        const token_str = try self.token.get_str();
        try std.fmt.format(buf.*.writer(), "{s} ", .{token_str});
        try self.name.debug_string(buf);
        try std.fmt.format(buf.*.writer(), " = ", .{});
        try self.expression.debug_string(buf);
        try std.fmt.format(buf.*.writer(), ";", .{});
    }
};

pub const RetStatement = struct {
    token: Token,
    expression: *const Expression,

    pub fn token_literal(self: RetStatement) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: RetStatement, buf: *std.ArrayList(u8)) DebugError!void {
        const token_str = try self.token.get_str();
        try std.fmt.format(buf.*.writer(), "{s} ", .{token_str});
        self.expression.debug_string(buf) catch return DebugError.DebugString;
        try std.fmt.format(buf.*.writer(), ";", .{});
    }
};

// To allow "statement" like: a + 10;
pub const ExprStatement = struct {
    token: Token,
    expression: *const Expression,

    pub fn token_literal(self: ExprStatement) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const ExprStatement, buf: *std.ArrayList(u8)) DebugError!void {
        self.expression.debug_string(buf) catch return DebugError.DebugString;
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn token_literal(self: Identifier) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: Identifier, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "{s}", .{self.value});
    }
};

pub const IntegerLiteral = struct {
    token: Token,
    value: i64,

    pub fn token_literal(self: IntegerLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const IntegerLiteral, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "{d}", .{self.value});
    }
};

pub const StringLiteral = struct {
    token: Token,
    value: []const u8,

    pub fn token_literal(self: StringLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const StringLiteral, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "{s}", .{self.value});
    }
};

pub const ArrayLiteral = struct {
    token: Token,
    elements: std.ArrayList(Expression),

    pub fn token_literal(self: ArrayLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const ArrayLiteral, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "[", .{});

        const len = self.elements.items.len;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            try self.elements.items[i].debug_string(buf);
            if (i != len - 1) {
                try std.fmt.format(buf.*.writer(), ", ", .{});
            }
        }

        try std.fmt.format(buf.*.writer(), "]", .{});
    }
};

pub const HashLiteral = struct {
    token: Token,
    pairs: std.StringHashMap(Expression),

    pub fn token_literal(self: HashLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const HashLiteral, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "{{", .{});

        const len = self.pairs.count();
        var iter = self.pairs.iterator();
        var i: u64 = 0;
        while (iter.next()) |item| : (i += 1) {
            const key = item.key_ptr.*;
            const value = item.value_ptr.*;

            try std.fmt.format(buf.*.writer(), "{s}: ", .{key});
            try value.debug_string(buf);
            if (i != len - 1) {
                try std.fmt.format(buf.*.writer(), ", ", .{});
            }
        }

        try std.fmt.format(buf.*.writer(), "}}", .{});
    }
};

pub const IndexExpression = struct {
    token: Token,
    left: *const Expression,
    index: *const Expression,

    pub fn token_literal(self: IndexExpression) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const IndexExpression, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "(", .{});
        self.left.debug_string(buf) catch return DebugError.DebugString;
        try std.fmt.format(buf.*.writer(), "[", .{});
        self.index.debug_string(buf) catch return DebugError.DebugString;
        try std.fmt.format(buf.*.writer(), "]", .{});
        try std.fmt.format(buf.*.writer(), ")", .{});
    }
};

pub const Boolean = struct {
    token: Token,
    value: bool,

    pub fn token_literal(self: Boolean) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const Boolean, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "{s}", .{self.token.literal});
    }
};

pub const PrefixExpr = struct {
    token: Token,
    operator: u8,
    right_expr: *const Expression,

    pub fn token_literal(self: PrefixExpr) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const PrefixExpr, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "(", .{});
        try std.fmt.format(buf.*.writer(), "{c}", .{self.operator});
        self.right_expr.debug_string(buf) catch return DebugError.DebugString;
        try std.fmt.format(buf.*.writer(), ")", .{});
    }
};

pub const InfixExpr = struct {
    token: Token,
    operator: []const u8,
    left_expr: *const Expression,
    right_expr: *const Expression,

    pub fn token_literal(self: InfixExpr) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const InfixExpr, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "(", .{});
        self.left_expr.debug_string(buf) catch return DebugError.DebugString;
        try std.fmt.format(buf.*.writer(), " {s} ", .{self.operator});
        self.right_expr.debug_string(buf) catch return DebugError.DebugString;
        try std.fmt.format(buf.*.writer(), ")", .{});
    }
};

pub const BlockStatement = struct {
    token: Token,
    statements: std.ArrayList(Statement),

    pub fn token_literal(self: BlockStatement) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: BlockStatement, buf: *std.ArrayList(u8)) DebugError!void {
        for (self.statements.items) |st| {
            try st.debug_string(buf);
        }
    }
};

pub const IfExpression = struct {
    token: Token,
    condition: *const Expression,
    consequence: BlockStatement,
    alternative: ?BlockStatement,

    pub fn token_literal(self: IfExpression) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const IfExpression, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "if ", .{});
        self.condition.debug_string(buf) catch return DebugError.DebugString;
        try std.fmt.format(buf.*.writer(), ":\n", .{});
        self.consequence.debug_string(buf) catch return DebugError.DebugString;
        if (self.alternative != null) {
            try std.fmt.format(buf.*.writer(), "\nelse:\n", .{});
            self.alternative.?.debug_string(buf) catch return DebugError.DebugString;
        }
        try std.fmt.format(buf.*.writer(), "\nend", .{});
    }
};

pub const FunctionLiteral = struct {
    token: Token,
    parameters: std.ArrayList(Identifier),
    body: BlockStatement,

    pub fn token_literal(self: FunctionLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const FunctionLiteral, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "fn(", .{});
        const len = self.parameters.items.len;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            try self.parameters.items[i].debug_string(buf);
            if (i != len - 1) {
                try std.fmt.format(buf.*.writer(), ",", .{});
            }
        }
        try std.fmt.format(buf.*.writer(), "):\n", .{});
        self.body.debug_string(buf) catch return DebugError.DebugString;
        try std.fmt.format(buf.*.writer(), "\nend", .{});
    }
};

pub const NamedFunction = struct {
    func_literal: *const FunctionLiteral,
    name: Identifier,

    pub fn token_literal(self: NamedFunction) []const u8 {
        return self.function_literal.token.literal ++ self.name.value;
    }

    pub fn debug_string(self: *const NamedFunction, buf: *std.ArrayList(u8)) DebugError!void {
        try std.fmt.format(buf.*.writer(), "fn {s}(", .{self.name.value});

        const params = self.func_literal.parameters.items;
        var i: usize = 0;
        while (i < params.len) : (i += 1) {
            try params[i].debug_string(buf);
            if (i != params.len - 1) {
                try std.fmt.format(buf.*.writer(), ",", .{});
            }
        }

        try std.fmt.format(buf.*.writer(), "):\n", .{});
        self.func_literal.body.debug_string(buf) catch return DebugError.DebugString;
        try std.fmt.format(buf.*.writer(), "\nend", .{});
    }
};

pub const CallExpression = struct {
    token: Token,
    function: *const Expression, // identifier or function literal
    arguments: std.ArrayList(Expression),

    pub fn token_literal(self: CallExpression) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: *const CallExpression, buf: *std.ArrayList(u8)) DebugError!void {
        try self.function.debug_string(buf);
        try std.fmt.format(buf.*.writer(), "(", .{});
        var i: usize = 0;
        const len = self.arguments.items.len;
        while (i < len) : (i += 1) {
            try self.arguments.items[i].debug_string(buf);
            if (i != len - 1) {
                try std.fmt.format(buf.*.writer(), ", ", .{});
            }
        }
        try std.fmt.format(buf.*.writer(), ")", .{});
    }
};
