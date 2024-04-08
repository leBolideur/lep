const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const ast = @import("ast.zig");

const ParseFnsError = error{ NoPrefixFn, NoInfixFn };
const ParserError = ParseFnsError || error{
    NotImpl,
    MissingToken,
    BadToken,
    MissingSemiCol,
    MissingColon,
    MissingEnd,
    MissingRightParen,
    MemAlloc,
    ParseExpr,
    ParseInteger,
    ParseIdentifier,
};

const Precedence = enum(u8) {
    LOWEST = 0,
    EQUALS,
    LG_OR_GT,
    SUM,
    PRODUCT,
    PREFIX,
    CALL,

    pub fn less_than(self: Precedence, prec: Precedence) bool {
        return @intFromEnum(self) < @intFromEnum(prec);
    }
};

const stderr = std.io.getStdErr().writer();

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    peek_token: Token,

    program: ast.Program,

    precedences_map: std.AutoHashMap(TokenType, Precedence),

    allocator: *const std.mem.Allocator,

    pub fn init(lexer: *Lexer, allocator: *const std.mem.Allocator) !Parser {
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

            .precedences_map = precedences_map,

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

        const expr_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
        expr_ptr.* = expression;

        if (!try self.expect_peek(TokenType.SEMICOLON)) return ParserError.MissingSemiCol;

        return ast.ExprStatement{
            .token = expr_st_token,
            .expression = expr_ptr,
        };
    }

    fn parse_expression(self: *Parser, precedence: Precedence) ParserError!ast.Expression {
        // Check if the current token may be a Prefix expr
        var left_expr = switch (self.current_token.type) {
            .IDENT => ast.Expression{ .identifier = try self.parse_identifier() },
            .INT => ast.Expression{ .integer = try self.parse_integer_literal() },
            .MINUS, .BANG => ast.Expression{ .prefix_expr = try self.parse_prefix_expression() },
            .TRUE, .FALSE => ast.Expression{ .boolean = try self.parse_boolean() },
            .LPAREN => try self.parse_grouped_expression(),
            .IF => ast.Expression{ .if_expression = try self.parse_if_expression() },
            else => {
                stderr.print("No prefix parse function for token: {s}\n", .{self.current_token.literal}) catch {};
                return ParseFnsError.NoPrefixFn;
            },
        };

        while (self.peek_token.type != TokenType.SEMICOLON and precedence.less_than(self.peek_precedence())) {
            const left_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
            left_ptr.* = left_expr;

            self.next();

            // Look for an Infix expr for the peek_token
            left_expr = switch (self.current_token.type) {
                .EQ,
                .NOT_EQ,
                .LT,
                .GT,
                .MINUS,
                .PLUS,
                .SLASH,
                .ASTERISK,
                => ast.Expression{ .infix_expr = try self.parse_infix_expression(left_ptr) },
                else => left_expr,
            };
        }

        return left_expr;
    }

    fn parse_identifier(self: *Parser) ParserError!ast.Identifier {
        return ast.Identifier{
            .token = self.current_token,
            .value = self.current_token.literal,
        };
    }

    fn parse_integer_literal(self: *Parser) ParserError!ast.IntegerLiteral {
        const to_int = std.fmt.parseInt(u64, self.current_token.literal, 10) catch {
            stderr.print("parse string {s} to int failed!\n", .{self.current_token.literal}) catch {};
            return ParserError.ParseInteger;
        };

        return ast.IntegerLiteral{
            .token = self.current_token,
            .value = to_int,
        };
    }

    fn parse_boolean(self: *Parser) ParserError!ast.Boolean {
        return ast.Boolean{
            .token = self.current_token,
            .value = self.current_token.type == TokenType.TRUE,
        };
    }

    fn parse_grouped_expression(self: *Parser) ParserError!ast.Expression {
        self.next();

        const expr = try self.parse_expression(Precedence.LOWEST);

        if (!try self.expect_peek(TokenType.RPAREN)) return ParserError.MissingRightParen;

        return expr;
    }

    fn parse_if_expression(self: *Parser) ParserError!ast.IfExpression {
        var if_expresssion = ast.IfExpression{
            .token = self.current_token,
            .condition = undefined,
            .consequence = undefined,
            .alternative = null,
        };
        self.next();

        var condition_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
        condition_ptr.* = try self.parse_expression(Precedence.LOWEST);
        if_expresssion.condition = condition_ptr;

        if (!try self.expect_peek(TokenType.COLON)) return ParserError.MissingColon;

        if_expresssion.consequence = try self.parse_statement_block();

        if (self.current_token.type == TokenType.ELSE) {
            if (!try self.expect_peek(TokenType.COLON)) return ParserError.MissingColon;
            if_expresssion.alternative = try self.parse_statement_block();
        }

        return if_expresssion;
    }

    fn parse_statement_block(self: *Parser) ParserError!ast.BlockStatement {
        var statements_list = std.ArrayList(ast.Statement).init(self.allocator.*);
        var block = ast.BlockStatement{
            .token = self.current_token,
            .statements = undefined,
        };
        self.next();

        while (!self.current_token_is(TokenType.END) and !self.current_token_is(TokenType.ELSE)) {
            const statement = try self.parse_statement();
            statements_list.append(statement) catch {};

            self.next();
        }

        block.statements = statements_list;

        return block;
    }

    fn parse_prefix_expression(self: *Parser) ParserError!ast.PrefixExpr {
        var prefix_expr = ast.PrefixExpr{
            .token = self.current_token,
            .operator = self.current_token.literal[0],
            .right_expr = undefined,
        };

        self.next();

        var right_expr_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;

        const right_expr = self.parse_expression(Precedence.PREFIX) catch {
            stderr.print("Error parsing right expression of Infixed one!\n", .{}) catch {};
            return ParserError.ParseExpr;
        };

        right_expr_ptr.* = right_expr;
        prefix_expr.right_expr = right_expr_ptr;

        return prefix_expr;
    }

    fn parse_infix_expression(self: *Parser, left: *const ast.Expression) ParserError!ast.InfixExpr {
        var infix_expr = ast.InfixExpr{
            .token = self.current_token,
            .operator = self.current_token.literal,
            .left_expr = left,
            .right_expr = undefined,
        };

        const precedence = self.current_precedence();
        self.next();

        var right_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;

        const right_expr = self.parse_expression(precedence) catch {
            stderr.print("Error parsing right expression of Infixed one!\n", .{}) catch {};
            return ParserError.ParseExpr;
        };

        right_ptr.* = right_expr;
        infix_expr.right_expr = right_ptr;

        return infix_expr;
    }

    fn expect_peek(self: *Parser, expected_type: TokenType) ParserError!bool {
        if (self.peek_token.type == expected_type) {
            self.next();
            return true;
        }
        stderr.print("Syntax error! Expected {!s}, got {!s}\n", .{
            self.current_token.get_str(),
            self.peek_token.get_str(),
        }) catch {};
        return ParserError.BadToken;
    }

    fn current_token_is(self: *Parser, token_type: TokenType) bool {
        return self.current_token.type == token_type;
    }

    fn peek_precedence(self: *Parser) Precedence {
        const prec = self.precedences_map.get(self.peek_token.type);
        return prec orelse Precedence.LOWEST;
    }

    fn current_precedence(self: *Parser) Precedence {
        const prec = self.precedences_map.get(self.current_token.type);
        return prec orelse Precedence.LOWEST;
    }
};
