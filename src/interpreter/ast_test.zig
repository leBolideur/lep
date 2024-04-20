const std = @import("std");

const Parser = @import("parser/parser.zig").Parser;
const ast = @import("ast/ast.zig");

const token = @import("lexer/token.zig");
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
            .expression = &ast.Expression{
                .identifier = ast.Identifier{
                    .token = Token{ .literal = "anotherVar", .type = TokenType.IDENT },
                    .value = "anotherVar",
                },
            },
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var program = ast.Program.init(&alloc);

    try program.statements.append(var_st);

    var buf = std.ArrayList(u8).init(alloc);

    try program.debug_string(&buf);
    const str = try buf.toOwnedSlice();
    try std.testing.expectEqualStrings("var myVar = anotherVar;", str);
}