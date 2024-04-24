const std = @import("std");

const common = @import("common");
const interpreter = @import("interpreter");
const compiler_ = @import("compiler");

const Lexer = common.lexer.Lexer;
const Parser = common.parser.Parser;
const Object = common.object.Object;
const ast = common.ast;

const token = interpreter.token;
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

test "Test String expression statement" {
    const expected = [_]struct { []const u8, []const u8 }{
        .{ "\"hello\";", "hello" },
        .{ "\"hello, world!\";", "hello, world!" },
        .{ "\"foo-bar?!@\";", "foo-bar?!@" },
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
        try test_string_literal(expr_st.expression, exp[1]);
    }
}

test "Test Array expression statement" {
    const expected = [_]struct { []const u8, usize }{
        .{ "[1, 2];", 2 },
        .{ "[0];", 1 },
        .{ "[];", 0 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const array = program.statements.items[0].expr_statement.expression.array;

        try std.testing.expect(@TypeOf(array) == ast.ArrayLiteral);
        try std.testing.expectEqual(array.elements.items.len, exp[1]);
    }
}

test "Test Array Index expression" {
    const expected = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "myArray[1 + 2];", "myArray", "(myArray[(1 + 2)]);" },
        .{ "some_array[1 * 2];", "some_array", "(some_array[(1 * 2)]);" },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const index_expr = program.statements.items[0].expr_statement.expression.index_expr;

        try std.testing.expect(@TypeOf(index_expr) == ast.IndexExpression);

        const array_left = index_expr.left;
        try test_identifier(array_left, exp[1]);

        // var buf = std.ArrayList(u8).init(std.testing.allocator);
        // defer buf.deinit();
        // try index_expr.debug_string(&buf);
        // const str = try buf.toOwnedSlice();
        // try std.testing.expectEqualStrings(str, exp[2]);

        // TODO: Complete...
    }
}

test "Test Hashes with Integers" {
    const expected = [_]struct { []const u8, u8, i64, i64 }{
        .{
            \\{"zip": 876, "age": 99};
            ,
            2,
            876,
            99,
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

        const hash = program.statements.items[0].expr_statement.expression.hash;

        try std.testing.expect(@TypeOf(hash) == ast.HashLiteral);

        var iter = hash.pairs.iterator();
        const count = hash.pairs.count();

        try std.testing.expectEqual(count, exp[1]);

        const expr1 = iter.next().?.value_ptr;
        try test_integer_literal(expr1, exp[2]);

        const expr2 = iter.next().?.value_ptr;
        try test_integer_literal(expr2, exp[3]);
    }
}

test "Test Hashes with String" {
    const expected = [_]struct { []const u8, u8, []const u8, []const u8 }{
        .{
            \\{"name": "John", "workAt": "fsociety"};
            ,
            2,
            "John",
            "fsociety",
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

        const hash = program.statements.items[0].expr_statement.expression.hash;

        try std.testing.expect(@TypeOf(hash) == ast.HashLiteral);

        var iter = hash.pairs.iterator();
        const count = hash.pairs.count();

        try std.testing.expectEqual(count, exp[1]);

        const expr1 = iter.next().?.value_ptr;
        try test_string_literal(expr1, exp[2]);

        const expr2 = iter.next().?.value_ptr;
        try test_string_literal(expr2, exp[3]);
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

test "Test function Literal parameters" {
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

        const func = program.statements.items[0].expr_statement.expression.func;
        const func_lit = switch (func) {
            .literal => |lit| lit,
            else => {
                @panic("Not a literal function\n");
            },
        };

        try std.testing.expect(@TypeOf(func_lit) == ast.FunctionLiteral);
        // try std.testing.expectEqualStrings(func_lit.name.value, exp[0]);
        try std.testing.expect(func_lit.parameters.items.len == exp[1]);
    }
}

test "Test Named function parameters" {
    const expected = [_]struct { []const u8, []const u8, i64 }{
        .{ "fn test(x, y): x + y; end", "test", 2 },
        .{ "fn test_u(x, y): x - y; end", "test_u", 2 },
        .{ "fn add(x, y, z): end", "add", 3 },
        .{ "fn print(x): x; end", "print", 1 },
        .{ "fn void(): end", "void", 0 },
    };

    for (expected) |exp| {
        var lexer = Lexer.init(exp[0]);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();

        var parser = try Parser.init(&lexer, &arena.allocator());

        const node = try parser.parse();
        const program = node.program;
        try std.testing.expect(program.statements.items.len == 1);

        const func = program.statements.items[0].expr_statement.expression.func;
        const named_func = switch (func) {
            .named => |named| named,
            else => {
                @panic("Not a named function\n");
            },
        };
        // const func_lit = expr_st.expression.func_literal;

        try std.testing.expect(@TypeOf(named_func) == ast.NamedFunction);
        try std.testing.expectEqualStrings(named_func.name.value, exp[1]);
        try std.testing.expect(named_func.func_literal.parameters.items.len == exp[2]);
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
        try test_boolean(expr_st.expression, exp[2]);
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
        // array index expressions
        .{
            "a * [1, 2, 3, 4][b * c] * d;",
            "((a * ([1, 2, 3, 4][(b * c)])) * d)",
        },
        .{
            "add(a * b[2], b[1], 2 * [1, 2][1]);",
            "add((a * (b[2])), (b[1]), (2 * ([1, 2][1])))",
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

fn test_string_literal(expression: *const ast.Expression, value: []const u8) !void {
    switch (expression.*) {
        .string => |str| {
            try std.testing.expect(@TypeOf(str) == ast.StringLiteral);
            try std.testing.expectEqual(str.token.type, TokenType.STRING);
            try std.testing.expectEqualStrings(str.value, value);
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
