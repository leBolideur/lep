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

    const alloc: std.mem.Allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    defer parser.close();

    const program = try parser.parse();
    try std.testing.expect(program.statements.items.len == 3);

    const expected_integers_lit = [_][]const u8{ "5", "10", "4242" };
    const expected_integers = [_]u64{ 5, 10, 4242 };

    for (program.statements.items, expected_integers_lit, expected_integers) |st, exp_lit, exp_int| {
        const expr_st = st.expr_statement;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try std.testing.expect(@TypeOf(expr_st.expression.integer) == ast.IntegerLiteral);
        try std.testing.expectEqual(expr_st.token.type, TokenType.INT);
        try std.testing.expectEqualStrings(expr_st.token.literal, exp_lit);

        const integer = expr_st.expression.integer;
        try std.testing.expectEqual(integer.value, exp_int);
    }
}

test "Test Prefix expressions" {
    const input =
        \\-5;
        \\!10;
    ;

    const alloc: std.mem.Allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, &alloc);
    defer parser.close();

    const program = try parser.parse();
    try std.testing.expect(program.statements.items.len == 2);

    const expected_integers = [_]u64{ 5, 10 };
    const expected_prefix = [_]u8{ '-', '!' };

    for (program.statements.items, expected_integers, expected_prefix) |st, exp_int, exp_prefix| {
        const expr_st = st.expr_statement;
        const prefix_expr = expr_st.expression.prefix_expr;

        try std.testing.expect(@TypeOf(expr_st) == ast.ExprStatement);
        try std.testing.expect(@TypeOf(prefix_expr) == ast.PrefixExpr);
        try std.testing.expectEqual(prefix_expr.operator, exp_prefix);

        const right_expr = prefix_expr.right_expr;
        try std.testing.expect(@TypeOf(right_expr.integer) == ast.IntegerLiteral);
        try std.testing.expectEqual(right_expr.integer.token.type, TokenType.INT);
        try std.testing.expectEqual(right_expr.integer.value, exp_int);

        // const integer = expr_st.expression.integer;
        // const int_value = try std.fmt.parseInt(u64, exp_int, 10);
        // try std.testing.expectEqual(integer.value, int_value);
    }
}
