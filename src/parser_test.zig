const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const ast = @import("ast.zig");

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

test "Test the parser" {
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

    // const expected_identifiers = .{
    //     "x", "y", "foobar",
    // };
    // const expected_values = [3]u8{ "5", "10", "838383" };

    for (program.statements.items) |st| {
        const var_st = st.var_statement;
        try std.testing.expectEqual(var_st.token.type, TokenType.VAR);
        // try std.testing.expectEqualSlices(u8, var_st.token_literal(), "var");

        // try std.testing.expectEqual(expected_identifiers, var_st.name.token_literal());
        // std.testing.expectEqual(expected_values[i], var_st.expression.);
    }
}
