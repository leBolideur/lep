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
    MissingLeftParen,
    MissingFuncIdent,
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

    // program: ast.Program,

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
        try precedences_map.put(TokenType.LPAREN, Precedence.CALL);

        return Parser{
            .lexer = lexer,
            .current_token = lexer.next(),
            .peek_token = lexer.next(),
            // .program = ast.Program.init(allocator),

            .precedences_map = precedences_map,

            .allocator = allocator,
        };
    }

    pub fn next(self: *Parser) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.next();
    }

    pub fn parse(self: *Parser) !ast.Node {
        var statements = std.ArrayList(ast.Statement).init(self.allocator.*);

        while (self.current_token.type != TokenType.EOF) {
            const st = try self.parse_statement();
            try statements.append(st);
            self.next();
        }

        return ast.Node{ .program = ast.Program{ .statements = statements } };
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
        _ = self.expect_peek(TokenType.IDENT) catch return ParserError.MissingToken;

        const ident_name = self.current_token.literal;
        const ident = ast.Identifier{ .token = self.current_token, .value = ident_name };

        _ = self.expect_peek(TokenType.ASSIGN) catch return ParserError.MissingToken;
        self.next();

        var expr_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
        expr_ptr.* = try self.parse_expression(Precedence.LOWEST);

        _ = try self.expect_peek(TokenType.SEMICOLON);

        return ast.VarStatement{
            .token = var_st_token,
            .name = ident,
            .expression = expr_ptr,
        };
    }

    fn parse_ret_statement(self: *Parser) !ast.RetStatement {
        const ret_st_token = self.current_token;
        self.next();

        var expr_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
        expr_ptr.* = try self.parse_expression(Precedence.LOWEST);

        _ = self.expect_peek(TokenType.SEMICOLON) catch return ParserError.MissingToken;

        return ast.RetStatement{
            .token = ret_st_token,
            .expression = expr_ptr,
        };
    }

    fn parse_expr_statement(self: *Parser) !ast.ExprStatement {
        const expr_st_token = self.current_token;
        const expression = try self.parse_expression(Precedence.LOWEST);

        const expr_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
        expr_ptr.* = expression;

        if (self.peek_token.type == TokenType.END or self.peek_token.type == TokenType.SEMICOLON) {
            self.next();
        }

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
            .FN => ast.Expression{ .func = try self.parse_function_literal() },
            else => {
                stderr.print("No prefix parse function for token > {s}\n", .{self.current_token.literal}) catch {};
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
                .LPAREN => ast.Expression{ .call_expression = try self.parse_call_expression(left_ptr) },
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
        const to_int = std.fmt.parseInt(i64, self.current_token.literal, 10) catch {
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

        _ = self.expect_peek(TokenType.RPAREN) catch return ParserError.MissingRightParen;

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

        _ = self.expect_peek(TokenType.COLON) catch return ParserError.MissingColon;

        if_expresssion.consequence = try self.parse_block_statement();

        if (self.current_token.type == TokenType.ELSE) {
            _ = self.expect_peek(TokenType.COLON) catch return ParserError.MissingColon;
            if_expresssion.alternative = try self.parse_block_statement();
        }

        return if_expresssion;
    }

    fn parse_block_statement(self: *Parser) ParserError!ast.BlockStatement {
        var statements_list = std.ArrayList(ast.Statement).init(self.allocator.*);
        var block = ast.BlockStatement{
            .token = self.current_token,
            .statements = undefined,
        };
        self.next();

        while (!self.expect_current(TokenType.END) and
            !self.expect_current(TokenType.ELSE) and
            !self.expect_current(TokenType.EOF))
        {
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
            stderr.print("Error parsing right expression of Prefixed one!\n", .{}) catch {};
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

    fn parse_function_literal(self: *Parser) ParserError!ast.Function {
        const lit_ptr = self.allocator.create(ast.FunctionLiteral) catch return ParserError.MemAlloc;

        lit_ptr.* = ast.FunctionLiteral{
            .token = self.current_token,
            .parameters = undefined,
            .body = undefined,
        };
        var named_func = ast.NamedFunction{
            .name = undefined,
            .func_literal = lit_ptr,
        };
        var is_named = false;

        if (self.peek_token.type == TokenType.IDENT) {
            _ = self.expect_peek(TokenType.IDENT) catch return ParserError.MissingFuncIdent;
            named_func.name = try self.parse_identifier();
            is_named = true;
        }

        _ = self.expect_peek(TokenType.LPAREN) catch return ParserError.MissingLeftParen;

        lit_ptr.*.parameters = try self.parse_function_parameters();
        _ = self.expect_peek(TokenType.COLON) catch return ParserError.MissingColon;

        lit_ptr.*.body = try self.parse_block_statement();

        if (is_named) {
            if (self.expect_current(TokenType.END)) {
                try self.unexpect_peek(TokenType.SEMICOLON);
                self.next();
            }
            // else {
            //     return ParserError.MissingEnd;
            // }

            return ast.Function{ .named = named_func };
        }

        if (self.expect_current(TokenType.SEMICOLON))
            self.next();

        return ast.Function{
            .literal = lit_ptr.*,
        };
    }

    fn parse_function_parameters(self: *Parser) ParserError!std.ArrayList(ast.Identifier) {
        var identifiers = std.ArrayList(ast.Identifier).init(self.allocator.*);

        if (self.peek_token.type == TokenType.RPAREN) {
            self.next();
            return identifiers;
        }

        self.next();
        var identifier = try self.parse_identifier();
        identifiers.append(identifier) catch {};

        while (self.peek_token.type == TokenType.COMMA) {
            self.next();
            self.next();

            identifier = try self.parse_identifier();
            identifiers.append(identifier) catch {};
        }

        _ = self.expect_peek(TokenType.RPAREN) catch return ParserError.MissingRightParen;

        return identifiers;
    }

    fn parse_call_expression(self: *Parser, function: *const ast.Expression) ParserError!ast.CallExpression {
        var call = ast.CallExpression{ .token = self.current_token, .arguments = undefined, .function = function };
        call.arguments = try self.parse_call_arguments();
        return call;
    }

    fn parse_call_arguments(self: *Parser) ParserError!std.ArrayList(ast.Expression) {
        var args = std.ArrayList(ast.Expression).init(self.allocator.*);

        if (self.peek_token.type == TokenType.RPAREN) {
            self.next();
            return args;
        }

        self.next();
        var arg = try self.parse_expression(Precedence.LOWEST);
        args.append(arg) catch {};

        while (self.peek_token.type == TokenType.COMMA) {
            self.next();
            self.next();

            arg = try self.parse_expression(Precedence.LOWEST);
            args.append(arg) catch {};
        }

        _ = self.expect_peek(TokenType.RPAREN) catch return ParserError.MissingRightParen;

        return args;
    }

    fn expect_peek(self: *Parser, expected_type: TokenType) ParserError!bool {
        if (self.peek_token.type == expected_type) {
            self.next();
            return true;
        }
        stderr.print("Syntax error! Expected '{!s}' before '{!s}'\n", .{
            expected_type.get_str_from_keyword(),
            self.peek_token.get_str(),
        }) catch {};
        return ParserError.BadToken;
    }

    fn expect_current(self: *Parser, token_type: TokenType) bool {
        return self.current_token.type == token_type;
    }

    fn unexpect_current(self: *Parser, expected_type: TokenType) ParserError!void {
        if (self.current_token.type == expected_type) {
            stderr.print("Syntax error! Too much {!s}\n", .{
                self.current_token.get_str(),
                // self.peek_token.get_str(),
            }) catch {};
            return ParserError.BadToken;
        }
    }

    fn unexpect_peek(self: *Parser, expected_type: TokenType) ParserError!void {
        if (self.peek_token.type == expected_type) {
            stderr.print("Syntax error! Too much {!s} after {!s}\n", .{
                self.peek_token.get_str(),
                self.current_token.get_str(),
            }) catch {};
            return ParserError.BadToken;
        }
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
