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
    var parser = Parser.init(&lexer, &alloc);
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
    var parser = Parser.init(&lexer, &alloc);
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
