const std = @import("std");

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const Node = union(enum) {
    statement: Statement,
    expression: Expression,

    pub fn token_literal(self: Node) void {
        switch (self) {
            .expression => |e| e.token_literal(),
            .statement => |s| s.token_literal(),
        }
    }
};

pub const Statement = union(enum) {
    var_statement: VarStatement,
};

const Expression = union(enum) {
    // Identifier can be an expression (use of binding) and a statement (bindig)
    identifier: Identifier,
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
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn token_literal(self: VarStatement) []const u8 {
        return self.token.literal;
    }
};
