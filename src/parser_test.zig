const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const ast = @import("ast.zig");

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

test "Test VAR statements" {
    const expected = [_]struct { []const u8, []const u8, i64 }{
        .{ "var x = 5;", "x", 5 },
        .{ "var y = 10;", "y", 10 },
        .{ "var foobar = 83;", "foobar", 83 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());
        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const var_st = program.statements.items[0].var_statement;

        try std.testing.expect(@TypeOf(var_st) == ast.VarStatement);
        try std.testing.expectEqual(var_st.token.type, TokenType.VAR);
        try std.testing.expectEqualStrings(var_st.token_literal(), "var");

        const ident = var_st.name;
        try std.testing.expect(@TypeOf(ident) == ast.Identifier);
        try std.testing.expectEqual(ident.token.type, TokenType.IDENT);
        try std.testing.expectEqualStrings(ident.value, exp[1]);

        try test_integer_literal(var_st.expression, exp[2]);
    }
}

test "Test RET statements" {
    const expected = [_]struct { []const u8, i64 }{
        .{ "ret 5;", 5 },
        .{ "ret 20;", 20 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;

        try std.testing.expect(program.statements.items.len == 1);
        const ret_st = program.statements.items[0].ret_statement;

        try std.testing.expect(@TypeOf(ret_st) == ast.RetStatement);
        try std.testing.expectEqual(ret_st.token.type, TokenType.RET);
        try std.testing.expectEqualStrings(ret_st.token_literal(), "ret");

        try test_integer_literal(ret_st.expression, exp[1]);
    }
}

test "Test Identifier expression statement" {
    const expected = [_]struct { []const u8, []const u8 }{
        .{ "foo;", "foo" },
        .{ "bar;", "bar" },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());
        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try test_identifier(expr_st.expression, exp[1]);
    }
}

test "Test Integer expression statement" {
    const expected = [_]struct { []const u8, []const u8, i64 }{
        .{ "5;", "5", 5 },
        .{ "10;", "10", 10 },
        .{ "42;", "42", 42 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try test_integer_literal(expr_st.expression, exp[2]);
        try std.testing.expectEqualStrings(expr_st.token.literal, exp[1]);
    }
}

test "Test If expression" {
    const expected = [_]struct { []const u8, []const u8, []const u8, []const u8, []const u8 }{
        .{ "if x == y:  x; end;", "x", "==", "y", "x" },
        .{ "if x != y:  y; end;", "x", "!=", "y", "y" },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement;
        const if_expr = expr_st.expression.if_expression;

        try std.testing.expect(@TypeOf(if_expr) == ast.IfExpression);
        try std.testing.expect(if_expr.consequence.statements.items.len == 1);

        const consequence = if_expr.consequence.statements.items[0];
        try test_identifier(consequence.expr_statement.expression, exp[4]);

        try std.testing.expect(if_expr.alternative == null);
    }
}

test "Test If-Else expression" {
    const expected = [_]struct { []const u8, []const u8, []const u8, []const u8, []const u8, []const u8 }{
        .{ "if x == y: x; else: y; end;", "x", "==", "y", "x", "y" },
        .{ "if x != y: y; else: x; end;", "x", "!=", "y", "y", "x" },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement.expression;
        const if_expr = expr_st.if_expression;

        try std.testing.expect(@TypeOf(if_expr) == ast.IfExpression);
        try std.testing.expect(if_expr.consequence.statements.items.len == 1);

        const consequence = if_expr.consequence.statements.items[0];
        try test_identifier(consequence.expr_statement.expression, exp[4]);

        try std.testing.expect(if_expr.alternative != null);

        const alternative = if_expr.alternative.?.statements.items[0];
        try test_identifier(alternative.expr_statement.expression, exp[5]);
    }
}

test "Test function literal parameters" {
    const expected = [_]struct { []const u8, i64 }{
        .{ "fn(x, y): x + y; end;", 2 },
        .{ "fn(x, y): x - y; end", 2 },
        .{ "fn(x, y, z): end;", 3 },
        .{ "fn(x): x; end", 1 },
        .{ "fn(): end;", 0 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement;
        const func_lit = expr_st.expression.func_literal;

        try std.testing.expect(@TypeOf(func_lit) == ast.FunctionLiteral);
        try std.testing.expect(func_lit.parameters.items.len == exp[1]);
    }
}

test "Test call expressions" {
    const expected = [_]struct { []const u8, []const u8, i64, i64, []const u8 }{
        .{ "add(1, 2);", "add", 1, 2, "add(1, 2)" },
        .{ "sub(5, 2);", "sub", 5, 2, "sub(5, 2)" },
        .{ "mul(12, 6);", "mul", 12, 6, "mul(12, 6)" },
        .{ "div(7, 3);", "div", 7, 3, "div(7, 3)" },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement;
        const call_expr = expr_st.expression.call_expression;

        try std.testing.expect(@TypeOf(call_expr) == ast.CallExpression);
        try test_identifier(call_expr.function, exp[1]);

        try std.testing.expect(call_expr.arguments.items.len == 2);
        try test_integer_literal(&call_expr.arguments.items[0], exp[2]);
        try test_integer_literal(&call_expr.arguments.items[1], exp[3]);

        var buf = std.ArrayList(u8).init(arena.allocator());

        try program.debug_string(&buf);
        const str = try buf.toOwnedSlice();
        try std.testing.expectEqualStrings(str, exp[4]);
    }
}

test "Test Boolean expression statement" {
    const expected = [_]struct { []const u8, []const u8, bool }{
        .{ "true;", "true", true },
        .{ "false;", "false", false },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement;
        const expr = expr_st.expression;

        try test_boolean(expr, exp[2]);
    }
}

test "Test Prefix expressions with Integer" {
    const expected = [2]struct { []const u8, u8, []const u8, i64 }{
        .{ "-5;", '-', "5", 5 },
        .{ "!10;", '!', "10", 10 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const st = program.statements.items[0];

        const expr_st = st.expr_statement;
        const prefix_expr = expr_st.expression.prefix_expr;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try std.testing.expect(@TypeOf(prefix_expr) == ast.PrefixExpr);
        try std.testing.expectEqual(prefix_expr.operator, exp[1]);

        const right_expr = prefix_expr.right_expr;
        try test_integer_literal(right_expr, exp[3]);
        try std.testing.expectEqualStrings(right_expr.integer.token.literal, exp[2]);
    }
}

test "Test Prefix expressions with Boolean" {
    const expected = [2]struct { []const u8, u8, bool }{
        .{ "!false;", '!', false },
        .{ "!true;", '!', true },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const st = program.statements.items[0];

        const expr_st = st.expr_statement;
        const prefix_expr = expr_st.expression.prefix_expr;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try std.testing.expect(@TypeOf(prefix_expr) == ast.PrefixExpr);
        try std.testing.expectEqual(prefix_expr.operator, exp[1]);

        const right_expr = prefix_expr.right_expr;
        try test_boolean(right_expr, exp[2]);
    }
}

test "Test Infix expressions with Integer" {
    const expected = [_]struct { []const u8, i64, []const u8, i64 }{
        .{ "5 + 2;", 5, "+", 2 },
        .{ "5 - 5;", 5, "-", 5 },
        .{ "5 * 5;", 5, "*", 5 },
        .{ "5 / 12;", 5, "/", 12 },
        .{ "5 < 2;", 5, "<", 2 },
        .{ "5 > 1;", 5, ">", 1 },
        .{ "5 == 52;", 5, "==", 52 },
        .{ "12 != 6;", 12, "!=", 6 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);
        const st = program.statements.items[0];

        const infix_expr = st.expr_statement.expression.infix_expr;
        try std.testing.expect(@TypeOf(infix_expr) == ast.InfixExpr);

        const left_expr = infix_expr.left_expr;
        try test_integer_literal(left_expr, exp[1]);

        try std.testing.expectEqualStrings(infix_expr.operator, exp[2]);

        const right_expr = infix_expr.right_expr;
        try test_integer_literal(right_expr, exp[3]);
    }
}

test "Test Infix expressions with Boolean" {
    const expected = [_]struct { []const u8, bool, []const u8, bool }{
        .{ "true == true;", true, "==", true },
        .{ "true != false;", true, "!=", false },
        .{ "false == false;", false, "==", false },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);
        const st = program.statements.items[0];

        const infix_expr = st.expr_statement.expression.infix_expr;
        try std.testing.expect(@TypeOf(infix_expr) == ast.InfixExpr);

        const left_expr = infix_expr.left_expr;
        try test_boolean(left_expr, exp[1]);

        try std.testing.expectEqualStrings(infix_expr.operator, exp[2]);

        const right_expr = infix_expr.right_expr;
        try test_boolean(right_expr, exp[3]);
    }
}

test "Test operators precedence" {
    const expected = [_]struct { []const u8, []const u8 }{
        .{
            "-a * b;",
            "((-a) * b)",
        },
        .{
            "a + b + c;",
            "((a + b) + c)",
        },
        .{
            "a + b - c;",
            "((a + b) - c)",
        },
        .{
            "a * b * c;",
            "((a * b) * c)",
        },
        .{
            "a * b / c;",
            "((a * b) / c)",
        },
        .{
            "a + b / c;",
            "(a + (b / c))",
        },
        .{
            "a + b * c + d / e - f;",
            "(((a + (b * c)) + (d / e)) - f)",
        },
        .{
            "5 > 4 == 3 < 4;",
            "((5 > 4) == (3 < 4))",
        },
        .{
            "3 + 4 * 5 == 3 * 1 + 4 * 5;",
            "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))",
        },
        .{
            "5 < 4 != 3 > 4;",
            "((5 < 4) != (3 > 4))",
        },
        .{
            "!-a;",
            "(!(-a))",
        },
        .{
            "true;",
            "true",
        },
        .{
            "false;",
            "false",
        },
        .{
            "3 > 5 == false;",
            "((3 > 5) == false)",
        },
        .{
            "3 < 5 == true;",
            "((3 < 5) == true)",
        },
        // test grouped expressions
        .{
            "1 + (2 + 3) + 4;",
            "((1 + (2 + 3)) + 4)",
        },
        .{
            "(5 + 5) * 2;",
            "((5 + 5) * 2)",
        },
        .{
            "2 / (5 + 5);",
            "(2 / (5 + 5))",
        },
        .{
            "-(5 + 5);",
            "(-(5 + 5))",
        },
        .{
            "!(true == true);",
            "(!(true == true))",
        },
        // Test function calls
        .{
            "a + add(b * c) + d;",
            "((a + add((b * c))) + d)",
        },
        .{
            "add(a, b, 1, 2 * 3, 4 + 5, add(6, 7 * 8));",
            "add(a, b, 1, (2 * 3), (4 + 5), add(6, (7 * 8)))",
        },
        .{
            "add(a + b + c * d / f + g);",
            "add((((a + b) + ((c * d) / f)) + g))",
        },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        var buf = std.ArrayList(u8).init(arena.allocator());

        try program.debug_string(&buf);
        const str = try buf.toOwnedSlice();
        try std.testing.expectEqualStrings(exp[1], str);
    }
}

fn test_integer_literal(expression: *const ast.Expression, value: i64) !void {
    switch (expression.*) {
        .integer => |int_lit| {
            try std.testing.expect(@TypeOf(int_lit) == ast.IntegerLiteral);
            try std.testing.expectEqual(int_lit.token.type, TokenType.INT);
            try std.testing.expectEqual(int_lit.value, value);
        },
        else => unreachable,
    }
}

fn test_identifier(expression: *const ast.Expression, value: []const u8) !void {
    switch (expression.*) {
        .identifier => |ident| {
            try std.testing.expect(@TypeOf(ident) == ast.Identifier);
            try std.testing.expectEqual(ident.token.type, TokenType.IDENT);
            try std.testing.expectEqualStrings(ident.token.literal, value);
            try std.testing.expectEqualStrings(ident.value, value);
        },
        else => unreachable,
    }
}

fn test_boolean(expression: *const ast.Expression, value: bool) !void {
    switch (expression.*) {
        .boolean => |boolean| {
            try std.testing.expect(@TypeOf(boolean) == ast.Boolean);
            const exp_tok_type = if (value) TokenType.TRUE else TokenType.FALSE;
            try std.testing.expectEqual(boolean.token.type, exp_tok_type);
            try std.testing.expectEqual(boolean.value, value);
        },
        else => unreachable,
    }
}
