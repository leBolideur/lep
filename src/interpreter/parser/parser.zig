const std = @import("std");

const Lexer = @import("../lexer/lexer.zig").Lexer;

const token = @import("../lexer/token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const ast = @import("../ast/ast.zig");

const ParseFnsError = error{ NoPrefixFn, NoInfixFn };
const ParserError = ParseFnsError || error{
    NotImpl,
    MissingToken,
    BadToken,
    MissingSemiCol,
    MissingColon,
    MissingEnd,
    MissingRightParen,
    MissingRightBracket,
    MemAlloc,
    ParseExpr,
    ParseInteger,
    ParseIdentifier,
    MissingLeftParen,
    MissingFuncIdent,
    HashPutError,
    ParserExit,
    UnknownError,
};

const Precedence = enum(u8) {
    LOWEST = 0,
    EQUALS,
    LG_OR_GT,
    SUM,
    PRODUCT,
    PREFIX,
    CALL,
    INDEX,

    pub fn less_than(self: Precedence, prec: Precedence) bool {
        return @intFromEnum(self) < @intFromEnum(prec);
    }
};

const stderr = std.io.getStdErr().writer();

const Error = struct {
    msg: []const u8,
};

const StatementOrError = union(enum) {
    statement: ast.Statement,
    var_st: ast.VarStatement,
    ret_st: ast.RetStatement,
    err: Error,

    pub fn new_error(allocator: *const std.mem.Allocator, comptime fmt: []const u8, args: anytype) !StatementOrError {
        const msg = std.fmt.allocPrint(allocator.*, fmt, args) catch return ParserError.MemAlloc;

        return StatementOrError{ .err = Error{ .msg = msg } };
    }
};

const ExprStatementOrError = union(enum) {
    expr_st: ast.ExprStatement,
    err: Error,
};

pub const Parser = struct {
    lexer: *Lexer,
    previous_token: Token,
    current_token: Token,
    peek_token: Token,

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
        try precedences_map.put(TokenType.LBRACK, Precedence.INDEX);

        return Parser{
            .lexer = lexer,
            .previous_token = undefined,
            .current_token = lexer.next(),
            .peek_token = lexer.next(),

            .precedences_map = precedences_map,

            .allocator = allocator,
        };
    }

    pub fn next(self: *Parser) void {
        self.previous_token = self.current_token;
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.next();
    }

    pub fn parse(self: *Parser) !ast.Node {
        var statements = std.ArrayList(ast.Statement).init(self.allocator.*);

        while (self.current_token.type != TokenType.EOF) {
            const statement = try self.parse_statement();
            switch (statement) {
                .err => |err| {
                    return ast.Node{ .err = err.msg };
                },
                .statement => {
                    try statements.append(statement.statement);
                    self.next();
                },
                .var_st => |var_st| {
                    const st = ast.Statement{ .var_statement = var_st };
                    try statements.append(st);
                    self.next();
                },
                .ret_st => |ret_st| {
                    const st = ast.Statement{ .ret_statement = ret_st };
                    try statements.append(st);
                    self.next();
                },
            }
        }

        return ast.Node{ .program = ast.Program{ .statements = statements } };
    }

    fn parse_statement(self: *Parser) !StatementOrError {
        return switch (self.current_token.type) {
            TokenType.VAR => {
                const var_statement = try self.parse_var_statement();
                switch (var_statement) {
                    .err => |err| {
                        return StatementOrError{ .err = err };
                    },
                    .var_st => |var_st| {
                        const st = ast.Statement{ .var_statement = var_st };
                        return StatementOrError{ .statement = st };
                    },
                    else => unreachable,
                }
            },
            TokenType.RET => {
                const ret_statement = try self.parse_ret_statement();
                switch (ret_statement) {
                    .err => |err| {
                        return StatementOrError{ .err = err };
                    },
                    .ret_st => |ret_st| {
                        const st = ast.Statement{ .ret_statement = ret_st };
                        return StatementOrError{ .statement = st };
                    },
                    else => unreachable,
                }
            },
            else => {
                const expr_statement = try self.parse_expr_statement();
                switch (expr_statement) {
                    .err => |err| {
                        return StatementOrError{ .err = err };
                    },
                    .expr_st => |expr_st| {
                        const st = ast.Statement{ .expr_statement = expr_st };
                        return StatementOrError{ .statement = st };
                    },
                }
            },
        };
    }

    fn parse_var_statement(self: *Parser) !StatementOrError {
        const var_st_token = self.current_token;
        var ok = try self.expect_peek(TokenType.IDENT);
        if (!ok) {
            return StatementOrError.new_error(self.allocator, "Syntax error! Expected '{!s}' after '{s}'. line: {d} @ {d}\n", .{
                TokenType.IDENT.get_token_string(),
                self.current_token.literal,
                self.current_token.line,
                self.current_token.col,
            }) catch return ParserError.MemAlloc;
        }

        const ident_name = self.current_token.literal;
        const ident = ast.Identifier{ .token = self.current_token, .value = ident_name };

        ok = try self.expect_peek(TokenType.ASSIGN);
        if (!ok) {
            return StatementOrError.new_error(self.allocator, "Syntax error! Expected '{!s}' after '{s}'. line: {d} @ {d}\n", .{
                TokenType.ASSIGN.get_token_string(),
                self.current_token.literal,
                self.current_token.line,
                self.current_token.col,
            }) catch return ParserError.MemAlloc;
        }
        self.next();

        var expr_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
        expr_ptr.* = try self.parse_expression(Precedence.LOWEST);

        ok = try self.expect_peek(TokenType.SEMICOLON);
        if (!ok) {
            return StatementOrError.new_error(self.allocator, "Syntax error! Expected '{!s}' after '{s}'. line: {d} @ {d}\n", .{
                TokenType.SEMICOLON.get_token_string(),
                self.current_token.literal,
                self.current_token.line,
                self.current_token.col,
            }) catch return ParserError.MemAlloc;
        }

        const var_st = ast.VarStatement{
            .token = var_st_token,
            .name = ident,
            .expression = expr_ptr,
        };

        return StatementOrError{ .var_st = var_st };
    }

    fn parse_ret_statement(self: *Parser) !StatementOrError {
        const ret_st_token = self.current_token;
        self.next();

        var expr_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
        expr_ptr.* = try self.parse_expression(Precedence.LOWEST);

        var ok = try self.expect_peek(TokenType.SEMICOLON);
        if (!ok) {
            return StatementOrError.new_error(self.allocator, "Syntax error! Expected '{!s}' after '{s}'. line: {d} @ {d}\n", .{
                TokenType.SEMICOLON.get_token_string(),
                self.current_token.literal,
                self.current_token.line,
                self.current_token.col,
            }) catch return ParserError.MemAlloc;
        }

        const ret_st = ast.RetStatement{
            .token = ret_st_token,
            .expression = expr_ptr,
        };

        return StatementOrError{ .ret_st = ret_st };
    }

    fn parse_expr_statement(self: *Parser) !ExprStatementOrError {
        const expr_st_token = self.current_token;
        const expression = self.parse_expression(Precedence.LOWEST) catch |err| {
            if (err == ParserError.NoPrefixFn) {
                const msg = std.fmt.allocPrint(
                    self.allocator.*,
                    "Parser error line {d}: unknown statement.\n",
                    .{self.current_token.line},
                ) catch return ParserError.MemAlloc;

                return ExprStatementOrError{ .err = Error{ .msg = msg } };
            }

            return ParserError.UnknownError;
        };

        const expr_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
        expr_ptr.* = expression;

        if (self.peek_token.type == TokenType.SEMICOLON) {
            _ = self.expect_peek(TokenType.SEMICOLON) catch return ParserError.MissingSemiCol;
        }

        const expr_st = ast.ExprStatement{
            .token = expr_st_token,
            .expression = expr_ptr,
        };

        return ExprStatementOrError{ .expr_st = expr_st };
    }

    fn parse_expression(self: *Parser, precedence: Precedence) ParserError!ast.Expression {
        var left_expr = switch (self.current_token.type) {
            .IDENT => ast.Expression{ .identifier = try self.parse_identifier() },
            .INT => ast.Expression{ .integer = try self.parse_integer_literal() },
            .STRING => ast.Expression{ .string = try self.parse_string_literal() },
            .LBRACK => ast.Expression{ .array = try self.parse_array_literal() },
            .LBRACE => ast.Expression{ .hash = try self.parse_hash_literal() },
            .MINUS, .BANG => ast.Expression{ .prefix_expr = try self.parse_prefix_expression() },
            .TRUE, .FALSE => ast.Expression{ .boolean = try self.parse_boolean() },
            .LPAREN => try self.parse_grouped_expression(),
            .IF => ast.Expression{ .if_expression = try self.parse_if_expression() },
            .FN => ast.Expression{ .func = try self.parse_function_literal() },
            else => {
                stderr.print("No prefix parse function for token '{s}'. line: {d} @ {d}\n", .{
                    self.current_token.literal,
                    self.current_token.line,
                    self.current_token.col,
                }) catch {};
                return ParseFnsError.NoPrefixFn;
            },
        };

        while (self.peek_token.type != TokenType.SEMICOLON and precedence.less_than(self.peek_precedence())) {
            const left_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
            left_ptr.* = left_expr;

            self.next();

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
                .LBRACK => ast.Expression{ .index_expr = try self.parse_index_expression(left_ptr) },
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
            stderr.print("parse string {s} to int failed. line: {d} @ {d}\n", .{
                self.current_token.literal,
                self.current_token.line,
                self.current_token.col,
            }) catch {};
            return ParserError.ParseInteger;
        };

        return ast.IntegerLiteral{
            .token = self.current_token,
            .value = to_int,
        };
    }

    fn parse_string_literal(self: *Parser) ParserError!ast.StringLiteral {
        return ast.StringLiteral{
            .token = self.current_token,
            .value = self.current_token.literal,
        };
    }

    fn parse_array_literal(self: *Parser) ParserError!ast.ArrayLiteral {
        return ast.ArrayLiteral{
            .token = self.current_token,
            .elements = try self.parse_expressions_list(TokenType.RBRACK),
        };
    }

    fn parse_hash_literal(self: *Parser) ParserError!ast.HashLiteral {
        var hash = ast.HashLiteral{
            .token = self.current_token,
            .pairs = std.StringHashMap(ast.Expression).init(self.allocator.*),
        };

        while (self.peek_token.type != TokenType.RBRACE) {
            self.next();
            const key = try self.parse_string_literal();

            _ = try self.expect_peek(TokenType.COLON);

            self.next();
            const value = try self.parse_expression(Precedence.LOWEST);

            hash.pairs.put(key.value, value) catch return ParserError.HashPutError;

            if (self.peek_token.type != TokenType.RBRACE)
                _ = try self.expect_peek(TokenType.COMMA);
        }

        _ = try self.expect_peek(TokenType.RBRACE);

        return hash;
    }

    fn parse_index_expression(self: *Parser, left: *const ast.Expression) ParserError!ast.IndexExpression {
        var index_expr = ast.IndexExpression{
            .token = self.current_token,
            .left = left,
            .index = undefined,
        };

        self.next();
        var index_ptr = self.allocator.create(ast.Expression) catch return ParserError.MemAlloc;
        index_ptr.* = try self.parse_expression(Precedence.LOWEST);
        index_expr.index = index_ptr;

        _ = try self.expect_peek(TokenType.RBRACK);

        return index_expr;
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

        while (!self.current_is(TokenType.END) and
            !self.current_is(TokenType.ELSE))
        {
            const statement = try self.parse_statement();
            switch (statement) {
                .err => |err| {
                    // return StatementOrError{ .err = err };
                    _ = err;
                    return ParserError.UnknownError;
                },
                .statement => |st| {
                    statements_list.append(st) catch {};

                    self.next();
                },
                .var_st => |var_st| {
                    const st = ast.Statement{ .var_statement = var_st };
                    statements_list.append(st) catch {};
                    self.next();
                },
                .ret_st => |ret_st| {
                    const st = ast.Statement{ .ret_statement = ret_st };
                    statements_list.append(st) catch {};
                    self.next();
                },
            }
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
            self.next();

            named_func.name = try self.parse_identifier();
            is_named = true;
        }

        _ = self.expect_peek(TokenType.LPAREN) catch return ParserError.MissingLeftParen;

        lit_ptr.*.parameters = try self.parse_function_parameters();
        _ = self.expect_peek(TokenType.COLON) catch return ParserError.MissingColon;

        lit_ptr.*.body = try self.parse_block_statement();

        if (is_named) {
            return ast.Function{ .named = named_func };
        }

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
        return ast.CallExpression{
            .token = self.current_token,
            .arguments = try self.parse_expressions_list(TokenType.RPAREN),
            .function = function,
        };
    }

    fn parse_expressions_list(self: *Parser, end: TokenType) ParserError!std.ArrayList(ast.Expression) {
        var list = std.ArrayList(ast.Expression).init(self.allocator.*);

        if (self.peek_token.type == end) {
            self.next();
            return list;
        }

        self.next();
        var arg = try self.parse_expression(Precedence.LOWEST);
        list.append(arg) catch {};

        while (self.peek_token.type == TokenType.COMMA) {
            self.next();
            self.next();

            arg = try self.parse_expression(Precedence.LOWEST);
            list.append(arg) catch {};
        }

        var err = ParserError.MissingRightParen;
        if (end == TokenType.RBRACK) {
            err = ParserError.MissingRightBracket;
        }

        _ = self.expect_peek(end) catch return err;

        return list;
    }

    fn expect_peek(self: *Parser, expected_type: TokenType) ParserError!bool {
        if (self.peek_token.type == expected_type) {
            self.next();
            return true;
        }
        return false;

        // stderr.print("Syntax error! Expected '{!s}' after '{s}'. line: {d} @ {d}\n", .{
        //     expected_type.get_token_string(),
        //     self.current_token.literal,
        //     self.current_token.line,
        //     self.current_token.col,
        // }) catch {};
        // return ParserError.BadToken;
    }

    fn current_is(self: *Parser, token_type: TokenType) bool {
        return self.current_token.type == token_type;
    }

    fn unexpect_peek(self: *Parser, expected_type: TokenType) ParserError!void {
        if (self.peek_token.type == expected_type) {
            stderr.print("Syntax error! Too much '{!s}' after '{!s}'. line: {d} @ {d}\n", .{
                self.peek_token.get_str(),
                self.current_token.get_str(),
                self.current_token.line,
                self.current_token.col + self.current_token.literal.len,
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
