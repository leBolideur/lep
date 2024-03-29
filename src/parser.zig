const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const ast = @import("ast.zig");

const ParseFnsError = error{NoPrefixFn};
const ParserError = ParseFnsError || error{ NotImpl, MissingToken, BadToken, MissingSemiCol };

const Precedence = enum { LOWEST, EQUALS, LG_OR_GT, SUM, PRODUCT, PREFIX, CALL };

const stderr = std.io.getStdErr().writer();

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    peek_token: Token,

    program: ast.Program,

    prefixParseFns: std.AutoHashMap(TokenType, *const fn (Parser) ?ast.Expression),

    allocator: *const std.mem.Allocator,

    pub fn init(lexer: *Lexer, allocator: *const std.mem.Allocator) !Parser {
        var prefixParseFns = std.AutoHashMap(TokenType, *const fn (Parser) ?ast.Expression).init(allocator.*);
        try prefixParseFns.put(TokenType.IDENT, Parser.parse_identifier);
        try prefixParseFns.put(TokenType.INT, Parser.parse_integer_literal);

        return Parser{
            .lexer = lexer,
            .current_token = lexer.next(),
            .peek_token = lexer.next(),
            .program = ast.Program.init(allocator),
            .prefixParseFns = prefixParseFns,
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
            TokenType.RET => ast.Statement{ .ret_statement = try self.parse_ret_statement() },
            else => ast.Statement{ .expr_statement = try self.parse_expr_statement() },
        };
    }

    fn parse_var_statement(self: *Parser) !ast.VarStatement {
        const var_st_token = self.current_token;
        if (!try self.expect_peek(TokenType.IDENT)) return ParserError.MissingToken;

        const ident_name = self.current_token.literal;
        const ident = ast.Identifier{ .token = self.current_token, .value = ident_name };

        if (!try self.expect_peek(TokenType.ASSIGN)) return ParserError.MissingToken;

        // TOFIX: skip expression
        while (self.current_token.type != TokenType.SEMICOLON)
            self.next();

        return ast.VarStatement{
            .token = var_st_token,
            .name = ident,
            .expression = undefined,
        };
    }

    fn parse_ret_statement(self: *Parser) !ast.RetStatement {
        const ret_st_token = self.current_token;
        // if (!try self.expect_peek(TokenType.IDENT)) return ParserError.MissingToken;

        // TOFIX: skip expression
        while (self.current_token.type != TokenType.SEMICOLON)
            self.next();

        return ast.RetStatement{
            .token = ret_st_token,
            .expression = undefined,
        };
    }

    fn parse_expr_statement(self: *Parser) !ast.ExprStatement {
        const expr_st_token = self.current_token;
        const expression = try self.parse_expression(Precedence.LOWEST);

        if (!try self.expect_peek(TokenType.SEMICOLON)) return ParserError.MissingSemiCol;

        return ast.ExprStatement{
            .token = expr_st_token,
            .expression = expression,
        };
    }

    fn parse_expression(self: Parser, precedence: Precedence) !ast.Expression {
        _ = precedence;
        const prefix = self.prefixParseFns.get(self.current_token.type);
        const leftExpr = prefix orelse return ParseFnsError.NoPrefixFn;

        return leftExpr(self).?;
    }

    fn parse_identifier(self: Parser) ?ast.Expression {
        return ast.Expression{
            .identifier = ast.Identifier{
                .token = self.current_token,
                .value = self.current_token.literal,
            },
        };
    }

    fn parse_integer_literal(self: Parser) ?ast.Expression {
        const to_int = std.fmt.parseInt(u64, self.current_token.literal, 10) catch {
            stderr.print("parse string {s} to int failed!\n", .{self.current_token.literal}) catch {};
            return null;
        };
        return ast.Expression{
            .integer = ast.IntegerLiteral{
                .token = self.current_token,
                .value = to_int,
            },
        };
    }

    fn expect_peek(self: *Parser, expected_type: TokenType) !bool {
        if (self.peek_token.type == expected_type) {
            self.next();
            return true;
        }
        try stderr.print("Syntax error! Expected {!s}, got {!s}\n", .{
            self.current_token.get_str(),
            self.peek_token.get_str(),
        });
        return ParserError.BadToken;
    }

    pub fn close(self: *Parser) void {
        self.program.close();
        self.prefixParseFns.deinit();
    }
};
