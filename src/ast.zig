const std = @import("std");

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

pub const Statement = union(enum) {
    var_statement: VarStatement,
    ret_statement: RetStatement,
    expr_statement: ExprStatement,

    pub fn debug_string(self: Statement, alloc: *const std.mem.Allocator) ![]const u8 {
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

    pub fn debug_string(self: Expression, alloc: *const std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .identifier => |id| id.debug_string(alloc),
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

    pub fn debug_string(self: Program) ![]const u8 {
        var buff = std.ArrayList(u8).init(self.allocator.*);
        defer buff.deinit();

        for (self.statements.items) |st| {
            const str = try st.debug_string(self.allocator);
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

    pub fn debug_string(self: VarStatement, alloc: *const std.mem.Allocator) ![]const u8 {
        var buff = std.ArrayList(u8).init(alloc.*);
        defer buff.deinit();

        const token_str = try self.token.get_str();
        const expr_str = try self.expression.debug_string(alloc);
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

    pub fn debug_string(self: RetStatement, alloc: *const std.mem.Allocator) ![]const u8 {
        var buff = std.ArrayList(u8).init(alloc.*);
        defer buff.deinit();

        const token_str = try self.token.get_str();
        const expr_str = try self.expression.debug_string(alloc);
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

    pub fn debug_string(self: ExprStatement, alloc: *const std.mem.Allocator) ![]const u8 {
        return try self.expression.debug_string(alloc);
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn token_literal(self: VarStatement) []const u8 {
        return self.token.literal;
    }

    pub fn debug_string(self: Identifier, _: *const std.mem.Allocator) ![]const u8 {
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

    pub fn debug_string(self: Identifier, alloc: *const std.mem.Allocator) ![]const u8 {
        var buff = std.ArrayList(u8).init(alloc.*);
        defer buff.deinit();

        try std.fmt.format(buff.writer(), "{d}", self.value);

        return buff.toOwnedSlice();
    }
};
