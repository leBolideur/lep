const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const ast = @import("ast.zig");

const ParserError = error{ NotImpl, MissingToken };

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    peek_token: Token,

    program: ast.Program,

    allocator: *const std.mem.Allocator,

    pub fn init(lexer: *Lexer, allocator: *const std.mem.Allocator) Parser {
        return Parser{
            .lexer = lexer,
            .current_token = lexer.next(),
            .peek_token = lexer.next(),
            .program = ast.Program.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn next(self: *Parser) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.next();
    }

    pub fn parse(self: *Parser) !ast.Program {
        while (self.current_token.type != TokenType.EOF) {
            const st = try self.parse_statement();
            try self.program.statements.append(st);

            self.next();
        }

        return self.program;
    }

    fn parse_statement(self: *Parser) !ast.Statement {
        return switch (self.current_token.type) {
            TokenType.VAR => ast.Statement{ .var_statement = try self.parse_var_statement() },
            else => return ParserError.NotImpl,
        };
    }

    fn parse_var_statement(self: *Parser) !ast.VarStatement {
        const var_token = self.current_token;
        if (!self.expect_peek(TokenType.IDENT)) return ParserError.MissingToken;

        const ident_name = self.peek_token.literal;
        const ident = ast.Identifier{ .token = self.current_token, .value = ident_name };

        if (!self.expect_peek(TokenType.ASSIGN)) return ParserError.MissingToken;

        // TOFIX: skip expression
        while (self.current_token.type != TokenType.SEMICOLON)
            self.next();

        return ast.VarStatement{
            .token = var_token,
            .name = ident,
            .expression = undefined,
        };
    }

    fn expect_peek(self: *Parser, expected_type: TokenType) bool {
        // std.debug.print("tok >> {?}\tpeek >> {?}\n", .{ self.current_token, self.peek_token });
        if (self.peek_token.type == expected_type) {
            self.next();
            return true;
        }
        return false;
    }

    pub fn close(self: Parser) void {
        self.program.close();
    }
};
