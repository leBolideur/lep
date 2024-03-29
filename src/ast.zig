const std = @import("std");

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const DebugError = anyerror || error{DebugString};

pub const Statement = union(enum) {
    var_statement: VarStatement,
    ret_statement: RetStatement,
    expr_statement: ExprStatement,

    pub fn debug_string(self: Statement, alloc: *const std.mem.Allocator) DebugError![]const u8 {
        return switch (self) {
            .var_statement => |vs| vs.debug_string(alloc),
            .ret_statement => |rs| rs.debug_string(alloc),
            .expr_statement => |es| es.debug_string(alloc),
        };
    }
};

pub const Expression = union(enum) {
    // Identifier can be an expression (use of binding) and a statement (binding)
    identifier: Identifier,
    integer: IntegerLiteral,
    prefix_expr: PrefixExpr,
    infix_expr: InfixExpr,

    pub fn debug_string(self: Expression, alloc: *const std.mem.Allocator) DebugError![]const u8 {
        return switch (self) {
            .identifier => |id| id.debug_string(alloc),
            .integer => |int| int.debug_string(alloc),
            .prefix_expr => |prf| prf.debug_string(alloc),
            .infix_expr => |inf| inf.debug_string(alloc),
        };
    }
};

pub const Program = struct {
    statements: std.ArrayList(Statement),

    allocator: *const std.mem.Allocator,

    pub fn init(allocator: *const std.mem.Allocator) Program {
        return Program{
            .statements = std.ArrayList(Statement).init(allocator.*),
            .allocator = allocator,
        };
    }

    pub fn token_literal(self: Program) []const u8 {
        if (self.statements.len > 0)
            return self.statements[0].token_literal();
        return "";
    }

    pub fn debug_string(self: Program) DebugError.DebugString![]const u8 {
        var buff = std.ArrayList(u8).init(self.allocator.*);
        defer buff.deinit();

        for (self.statements.items) |st| {
            const str = st.debug_string(self.allocator) catch return DebugError.DebugString;
            defer self.allocator.free(str);
            try buff.appendSlice(str);
        }

        return buff.toOwnedSlice();
    }

    pub fn close(self: Program) void {
        self.statements.deinit();
    }
};

pub const VarStatement = struct {
    token: Token,
    name: Identifier,
    expression: Expression,

    pub fn token_literal(self: VarStatement) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: VarStatement, alloc: *const std.mem.Allocator) DebugError![]const u8 {
        var buff = std.ArrayList(u8).init(alloc.*);
        defer buff.deinit();

        const token_str = try self.token.get_str();
        const expr_str = self.expression.debug_string(alloc) catch return DebugError.DebugString;
        try std.fmt.format(buff.writer(), "{s} {s} = {s};", .{ token_str, self.name.value, expr_str });

        return buff.toOwnedSlice();
    }
};

pub const RetStatement = struct {
    token: Token,
    expression: Expression,

    pub fn token_literal(self: RetStatement) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: RetStatement, alloc: *const std.mem.Allocator) DebugError![]const u8 {
        var buff = std.ArrayList(u8).init(alloc.*);
        defer buff.deinit();

        const token_str = try self.token.get_str();
        const expr_str = self.expression.debug_string(alloc) catch return DebugError.DebugString;
        try std.fmt.format(buff.writer(), "{s} {s};", .{ token_str, expr_str });

        return buff.toOwnedSlice();
    }
};

// To allow "statement" like: a + 10;
pub const ExprStatement = struct {
    // The first token of the expression
    token: Token,
    expression: Expression,

    pub fn token_literal(self: ExprStatement) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: ExprStatement, alloc: *const std.mem.Allocator) DebugError![]const u8 {
        return self.expression.debug_string(alloc) catch return DebugError.DebugString;
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn token_literal(self: Identifier) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: Identifier, _: *const std.mem.Allocator) DebugError![]const u8 {
        // var buff = std.ArrayList(u8).init(alloc.*);
        // defer buff.deinit();

        // try buff.appendSlice(self.value);

        return self.value;
    }
};

pub const IntegerLiteral = struct {
    token: Token,
    value: u64,

    pub fn token_literal(self: IntegerLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: IntegerLiteral, alloc: *const std.mem.Allocator) ![]const u8 {
        var buff = std.ArrayList(u8).init(alloc.*);
        defer buff.deinit();

        try std.fmt.format(buff.writer(), "{d}", .{self.value});

        return buff.toOwnedSlice();
    }
};

pub const PrefixExpr = struct {
    token: Token,
    operator: u8,
    right_expr: *const Expression,

    pub fn token_literal(self: PrefixExpr) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: PrefixExpr, alloc: *const std.mem.Allocator) ![]const u8 {
        var buff = std.ArrayList(u8).init(alloc.*);
        defer buff.deinit();

        const right_str = self.right_expr.debug_string(alloc) catch return DebugError.DebugString;
        try std.fmt.format(buff.writer(), "({d}{s})", .{ self.operator, right_str });

        return buff.toOwnedSlice();
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

    pub fn debug_string(self: InfixExpr, alloc: *const std.mem.Allocator) ![]const u8 {
        var buff = std.ArrayList(u8).init(alloc.*);
        defer buff.deinit();

        const left_str = self.left_expr.debug_string(alloc) catch return DebugError.DebugString;
        const right_str = self.right_expr.debug_string(alloc) catch return DebugError.DebugString;
        try std.fmt.format(buff.writer(), "({s} {s} {s})", .{ left_str, self.operator, right_str });

        return buff.toOwnedSlice();
    }
};
