const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const ast = @import("ast.zig");

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

test "Test VAR statements" {
    const input =
        \\var x = 5;
        \\var y = 10;
        \\var foobar = 838383;
    ;

    const alloc: std.mem.Allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    defer parser.close();

    const program = try parser.parse();
    try std.testing.expect(program.statements.items.len == 3);

    const expected_identifiers = [_][]const u8{ "x", "y", "foobar" };
    // const expected_values = [3]u8{ "5", "10", "838383" };

    for (program.statements.items, expected_identifiers) |st, id| {
        const var_st = st.var_statement;

        try std.testing.expect(@TypeOf(var_st) == ast.VarStatement);
        try std.testing.expectEqual(var_st.token.type, TokenType.VAR);
        try std.testing.expectEqualStrings(var_st.token_literal(), "var");

        const ident = var_st.name;
        try std.testing.expect(@TypeOf(ident) == ast.Identifier);
        try std.testing.expectEqual(ident.token.type, TokenType.IDENT);
        try std.testing.expectEqualStrings(ident.value, id);

        // try std.testing.expectEqual(expected_identifiers, var_st.name.token_literal());
        // std.testing.expectEqual(expected_values[i], var_st.expression.);
    }
}

test "Test RET statements" {
    const input =
        \\ret 5;
        \\ret 10;
        \\ret 838383;
    ;

    const alloc: std.mem.Allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    defer parser.close();

    const program = try parser.parse();
    try std.testing.expect(program.statements.items.len == 3);

    // const expected_values = [3]u8{ "5", "10", "838383" };

    for (program.statements.items) |st| {
        const ret_st = st.ret_statement;

        try std.testing.expect(@TypeOf(ret_st) == ast.RetStatement);
        try std.testing.expectEqual(ret_st.token.type, TokenType.RET);
        try std.testing.expectEqualStrings(ret_st.token_literal(), "ret");

        // try std.testing.expectEqual(expected_identifiers, var_st.name.token_literal());
        // std.testing.expectEqual(expected_values[i], var_st.expression.);
    }
}

test "Test Identifier expression statement" {
    const expected = [_]struct { []const u8, []const u8 }{
        .{ "foo;", "foo" },
        .{ "bar;", "bar" },
    };

    for (expected) |exp| {
        const alloc: std.mem.Allocator = std.testing.allocator;
        var lexer = Lexer.init(exp[0]);
        var parser = try Parser.init(&lexer, &alloc);
        defer parser.close();

        const program = try parser.parse();
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try test_identifier(expr_st.expression, exp[1]);
    }
}

test "Test Integer expression statement" {
    const expected = [_]struct { []const u8, []const u8, u64 }{
        .{ "5;", "5", 5 },
        .{ "10;", "10", 10 },
        .{ "42;", "42", 42 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var parser = try Parser.init(&lexer, &std.testing.allocator);
        defer parser.close();

        const program = try parser.parse();
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try test_integer_literal(expr_st.expression, exp[2]);
        try std.testing.expectEqualStrings(expr_st.token.literal, exp[1]);
    }
}

test "Test Boolean expression statement" {
    const expected = [_]struct { []const u8, []const u8, bool }{
        .{ "true;", "true", true },
        .{ "false;", "false", false },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var parser = try Parser.init(&lexer, &std.testing.allocator);
        defer parser.close();

        const program = try parser.parse();
        try std.testing.expect(program.statements.items.len == 1);

        const expr_st = program.statements.items[0].expr_statement;
        const expr = expr_st.expression;

        try test_boolean(expr, exp[2]);
    }
}

test "Test Prefix expressions with Integer" {
    const expected = [2]struct { []const u8, u8, []const u8, u64 }{
        .{ "-5;", '-', "5", 5 },
        .{ "!10;", '!', "10", 10 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var parser = try Parser.init(&lexer, &std.testing.allocator);
        defer parser.close();

        const program = try parser.parse();
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
        var parser = try Parser.init(&lexer, &std.testing.allocator);
        defer parser.close();

        const program = try parser.parse();
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
    const expected = [_]struct { []const u8, u64, []const u8, u64 }{
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
        var parser = try Parser.init(&lexer, &std.testing.allocator);
        defer parser.close();

        const program = try parser.parse();
        try std.testing.expect(program.statements.items.len == 1);
        const st = program.statements.items[0];

        const expr = st.expr_statement.expression;
        const infix_expr = expr.infix_expr;
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
        var parser = try Parser.init(&lexer, &std.testing.allocator);
        defer parser.close();

        const program = try parser.parse();
        try std.testing.expect(program.statements.items.len == 1);
        const st = program.statements.items[0];

        const expr = st.expr_statement.expression;
        const infix_expr = expr.infix_expr;
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
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var parser = try Parser.init(&lexer, &std.testing.allocator);
        defer parser.close();

        const program = try parser.parse();
        try std.testing.expect(program.statements.items.len == 1);

        const str = try program.debug_string();
        defer std.testing.allocator.free(str);
        try std.testing.expectEqualStrings(exp[1], str);
    }
}

fn test_literal(expression: *const ast.Expression, value: anytype) !void {
    switch (expression.*) {
        .boolean => try test_boolean(expression, value),
        .integer => try test_integer_literal(expression, value),
        .identifier => try test_identifier(expression, value),
        else => unreachable,
    }
}

fn test_integer_literal(expression: *const ast.Expression, value: u64) !void {
    switch (expression.*) {
        .integer => |int| {
            try std.testing.expect(@TypeOf(int) == ast.IntegerLiteral);
            try std.testing.expectEqual(int.token.type, TokenType.INT);
            try std.testing.expectEqual(int.value, value);
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
            const exp_tok_type = if (value) TokenType.TRUE else TokenType.FALSE;

            try std.testing.expect(@TypeOf(boolean) == ast.Boolean);
            try std.testing.expectEqual(boolean.token.type, exp_tok_type);
            // try std.testing.expectEqualStrings(boolean.token.literal, value);
            try std.testing.expectEqual(boolean.value, value);
        },
        else => unreachable,
    }
}
