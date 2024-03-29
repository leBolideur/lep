const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const ast = @import("ast.zig");

const ParseFnsError = error{ NoPrefixFn, NoInfixFn };
const ParserError = ParseFnsError || error{ NotImpl, MissingToken, BadToken, MissingSemiCol };

const Precedence = enum { LOWEST, EQUALS, LG_OR_GT, SUM, PRODUCT, PREFIX, CALL };

const stderr = std.io.getStdErr().writer();

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    peek_token: Token,

    program: ast.Program,

    prefix_parse_fns: std.AutoHashMap(TokenType, *const fn (*Parser) ?ast.Expression),
    infix_parse_fns: std.AutoHashMap(TokenType, *const fn (*Parser, *const ast.Expression) ?ast.Expression),

    precedences_map: std.AutoHashMap(TokenType, Precedence),

    alloc_expressions: std.ArrayList(*ast.Expression),

    allocator: *const std.mem.Allocator,

    pub fn init(lexer: *Lexer, allocator: *const std.mem.Allocator) !Parser {
        var prefix_parse_fns = std.AutoHashMap(TokenType, *const fn (*Parser) ?ast.Expression).init(allocator.*);
        try prefix_parse_fns.put(TokenType.IDENT, Parser.parse_identifier);
        try prefix_parse_fns.put(TokenType.INT, Parser.parse_integer_literal);
        try prefix_parse_fns.put(TokenType.MINUS, Parser.parse_prefix_expression);
        try prefix_parse_fns.put(TokenType.BANG, Parser.parse_prefix_expression);

        var infix_parse_fns = std.AutoHashMap(TokenType, *const fn (*Parser, *const ast.Expression) ?ast.Expression).init(allocator.*);
        try infix_parse_fns.put(TokenType.MINUS, Parser.parse_infix_expression);
        try infix_parse_fns.put(TokenType.PLUS, Parser.parse_infix_expression);
        try infix_parse_fns.put(TokenType.ASTERISK, Parser.parse_infix_expression);
        try infix_parse_fns.put(TokenType.SLASH, Parser.parse_infix_expression);
        try infix_parse_fns.put(TokenType.EQ, Parser.parse_infix_expression);
        try infix_parse_fns.put(TokenType.NOT_EQ, Parser.parse_infix_expression);
        try infix_parse_fns.put(TokenType.LT, Parser.parse_infix_expression);
        try infix_parse_fns.put(TokenType.GT, Parser.parse_infix_expression);

        var precedences_map = std.AutoHashMap(TokenType, Precedence).init(allocator.*);
        try precedences_map.put(TokenType.EQ, Precedence.EQUALS);
        try precedences_map.put(TokenType.NOT_EQ, Precedence.EQUALS);
        try precedences_map.put(TokenType.LT, Precedence.LG_OR_GT);
        try precedences_map.put(TokenType.GT, Precedence.LG_OR_GT);
        try precedences_map.put(TokenType.PLUS, Precedence.SUM);
        try precedences_map.put(TokenType.MINUS, Precedence.SUM);
        try precedences_map.put(TokenType.SLASH, Precedence.PRODUCT);
        try precedences_map.put(TokenType.ASTERISK, Precedence.PRODUCT);

        return Parser{
            .lexer = lexer,
            .current_token = lexer.next(),
            .peek_token = lexer.next(),
            .program = ast.Program.init(allocator),

            .prefix_parse_fns = prefix_parse_fns,
            .infix_parse_fns = infix_parse_fns,

            .precedences_map = precedences_map,

            .alloc_expressions = std.ArrayList(*ast.Expression).init(allocator.*),

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

    fn parse_expression(self: *Parser, precedence: Precedence) !ast.Expression {
        const prefix = self.prefix_parse_fns.get(self.current_token.type);
        const prefix_fn = prefix orelse return ParseFnsError.NoPrefixFn;

        var left_expr: ast.Expression = prefix_fn(self).?;

        while (self.peek_token.type != TokenType.SEMICOLON and
            @intFromEnum(precedence) < @intFromEnum(self.peek_precedence()))
        {
            // std.debug.print("\nloop tok >>> {?}\n", .{self.peek_token.type});
            const infix_fn = self.infix_parse_fns.get(self.peek_token.type) orelse return left_expr;

            self.next();
            left_expr = infix_fn(self, &left_expr).?;
            std.debug.print("\nloop left >>> {?}\n", .{left_expr});
        }

        return left_expr;
    }

    fn parse_identifier(self: *Parser) ?ast.Expression {
        return ast.Expression{
            .identifier = ast.Identifier{
                .token = self.current_token,
                .value = self.current_token.literal,
            },
        };
    }

    fn parse_integer_literal(self: *Parser) ?ast.Expression {
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

    fn parse_prefix_expression(self: *Parser) ?ast.Expression {
        var return_expr = ast.Expression{
            .prefix_expr = ast.PrefixExpr{
                .token = self.current_token,
                .operator = self.current_token.literal[0],
                .right_expr = undefined,
            },
        };

        self.next();

        var alloc_expr = self.allocator.create(ast.Expression) catch return null;
        self.alloc_expressions.append(alloc_expr) catch return null;
        alloc_expr.* = self.parse_expression(Precedence.PREFIX) catch {
            stderr.print("Error parsing right expression of prefixed one!\n", .{}) catch {};
            return null;
        };

        return_expr.prefix_expr.right_expr = alloc_expr;

        return return_expr;
    }

    fn parse_infix_expression(self: *Parser, left: *const ast.Expression) ?ast.Expression {
        // std.debug.print("parse - curr: {?}\t{s}\n", .{ self.current_token.type, self.current_token.literal });
        var return_expr = ast.Expression{
            .infix_expr = ast.InfixExpr{
                .token = self.current_token,
                .operator = self.current_token.literal,
                .left_expr = left,
                .right_expr = undefined,
            },
        };

        const precedence = self.current_precedence();
        self.next();

        var alloc_expr = self.allocator.create(ast.Expression) catch return null;
        self.alloc_expressions.append(alloc_expr) catch return null;
        alloc_expr.* = self.parse_expression(precedence) catch {
            stderr.print("Error parsing right expression of prefixed one!\n", .{}) catch {};
            return null;
        };

        return_expr.infix_expr.right_expr = alloc_expr;

        return return_expr;
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

    fn peek_precedence(self: *Parser) Precedence {
        const prec = self.precedences_map.get(self.peek_token.type);
        return prec orelse Precedence.LOWEST;
    }

    fn current_precedence(self: *Parser) Precedence {
        const prec = self.precedences_map.get(self.current_token.type);
        return prec orelse Precedence.LOWEST;
    }

    pub fn close(self: *Parser) void {
        self.program.close();
        self.prefix_parse_fns.deinit();
        self.infix_parse_fns.deinit();

        self.precedences_map.deinit();

        for (self.alloc_expressions.items) |alloc| {
            self.allocator.destroy(alloc);
        }
        self.alloc_expressions.deinit();
    }
};
