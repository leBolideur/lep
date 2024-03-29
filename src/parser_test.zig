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
    const input =
        \\foo;
        \\bar;
    ;

    const alloc: std.mem.Allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    defer parser.close();

    const program = try parser.parse();
    try std.testing.expect(program.statements.items.len == 2);

    const expected_identifiers = [_][]const u8{ "foo", "bar" };

    for (program.statements.items, expected_identifiers) |st, expected| {
        const expr_st = st.expr_statement;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try std.testing.expect(@TypeOf(expr_st.expression.identifier) == ast.Identifier);
        try std.testing.expectEqual(expr_st.token.type, TokenType.IDENT);
        try std.testing.expectEqualStrings(expr_st.token.literal, expected);

        const ident = expr_st.expression.identifier;
        try std.testing.expectEqualStrings(ident.value, expected);
    }
}

test "Test Integer expression statement" {
    const input =
        \\5;
        \\10;
        \\4242;
    ;

    const expected = [3]struct { []const u8, u16 }{
        .{ "5", 5 },
        .{ "10", 10 },
        .{ "4242", 4242 },
    };

    const alloc: std.mem.Allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    defer parser.close();

    const program = try parser.parse();
    try std.testing.expect(program.statements.items.len == 3);

    for (program.statements.items, expected) |st, exp| {
        const expr_st = st.expr_statement;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try std.testing.expect(@TypeOf(expr_st.expression.integer) == ast.IntegerLiteral);
        try std.testing.expectEqual(expr_st.token.type, TokenType.INT);
        try std.testing.expectEqualStrings(expr_st.token.literal, exp[0]);

        const integer = expr_st.expression.integer;
        try std.testing.expectEqual(integer.value, exp[1]);
    }
}

test "Test Prefix expressions" {
    const input =
        \\-5;
        \\!10;
    ;

    const expected = [2]struct { u8, []const u8, u8 }{
        .{ '-', "5", 5 },
        .{ '!', "10", 10 },
    };

    const alloc: std.mem.Allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    defer parser.close();

    const program = try parser.parse();
    try std.testing.expect(program.statements.items.len == 2);

    for (program.statements.items, expected) |st, exp| {
        const expr_st = st.expr_statement;
        const prefix_expr = expr_st.expression.prefix_expr;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try std.testing.expect(@TypeOf(prefix_expr) == ast.PrefixExpr);
        try std.testing.expectEqual(prefix_expr.operator, exp[0]);

        const right_expr = prefix_expr.right_expr;
        try std.testing.expect(@TypeOf(right_expr.integer) == ast.IntegerLiteral);
        try std.testing.expectEqual(right_expr.integer.token.type, TokenType.INT);
        try std.testing.expectEqualStrings(right_expr.integer.token.literal, exp[1]);
        try std.testing.expectEqual(right_expr.integer.value, exp[2]);
    }
}

test "Test Infix expressions" {
    const input =
        \\15 + 2;
        \\5 - 5;
        \\5 * 5;
        \\5 / 5;
        \\5 < 5;
        \\5 > 5;
        \\5 == 5;
        \\5 != 5;
    ;

    const expected = [_]struct { u8, []const u8, u8 }{
        .{ 15, "+", 2 },
        .{ 5, "-", 5 },
        .{ 5, "*", 5 },
        .{ 5, "/", 5 },
        .{ 5, "<", 5 },
        .{ 5, ">", 5 },
        .{ 5, "==", 5 },
        .{ 5, "!=", 5 },
    };

    const alloc: std.mem.Allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    defer parser.close();

    const program = try parser.parse();
    try std.testing.expect(program.statements.items.len == 8);

    for (program.statements.items, expected) |st, exp| {
        const expr_st = st.expr_statement;
        const expr = expr_st.expression;

        try std.testing.expect(@TypeOf(expr) == ast.Expression);

        const infix_expr = expr.infix_expr;
        try std.testing.expect(@TypeOf(infix_expr) == ast.InfixExpr);

        const left_expr = infix_expr.left_expr;
        try test_integer_literal(left_expr, exp[0]);

        try std.testing.expectEqualStrings(infix_expr.operator, exp[1]);

        const right_expr = infix_expr.right_expr;
        try test_integer_literal(right_expr, exp[2]);
    }
}

fn test_integer_literal(expression: *const ast.Expression, value: u8) !void {
    // std.debug.print("\n\tExpr >>> {?}\n", .{expression.identifier.token.type});
    const int = expression.integer;
    // _ = int;
    // try std.testing.expect(@TypeOf(int) == ast.IntegerLiteral);
    // try std.testing.expectEqual(int.token.type, TokenType.INT);
    // try std.testing.expectEqual(int.value, value);

    try std.testing.expect(@TypeOf(int) == ast.IntegerLiteral);
    try std.testing.expectEqual(int.token.type, TokenType.INT);
    try std.testing.expectEqual(int.value, value);
}
