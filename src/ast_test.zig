const std = @import("std");

const Parser = @import("parser.zig").Parser;
const ast = @import("ast.zig");

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

test "Test the AST string debug" {
    // test with the following Lep code: var myVar = anotherVar;

    const var_st = ast.Statement{
        .var_statement = ast.VarStatement{
            .token = Token{ .literal = "var", .type = TokenType.VAR },
            .name = ast.Identifier{
                .token = Token{ .literal = "myVar", .type = TokenType.IDENT },
                .value = "myVar",
            },
            .expression = ast.Expression{
                .identifier = ast.Identifier{
                    .token = Token{ .literal = "anotherVar", .type = TokenType.IDENT },
                    .value = "anotherVar",
                },
            },
        },
    };

    var program = ast.Program.init(&std.testing.allocator);
    defer program.close();

    try program.statements.append(var_st);
    const string = try program.debug_string();
    try std.testing.expectEqualStrings("var myVar = anotherVar;", string);

    std.testing.allocator.free(string);
}
