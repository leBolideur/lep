const std = @import("std");

// Why those import doesn't works: error: unable to load 'lexer/token.zig': FileNotFound
const token_import = @import("lexer/token.zig");
const Token = token_import.Token;
const TokenType = token_import.TokenType;

const Lexer = @import("lexer/lexer.zig").Lexer;

test "Test the lexer" {
    const input =
        \\var my_number = 1 + 20;
        \\fn my_func(number):
        \\ret number + 1;
        \\end;
        \\var other = my_func(4);
        \\!-/*5;
        \\5 < 10 > 5;
        \\if 5 < 10:
        \\ret true;
        \\else:
        \\ret false;
        \\end;
        \\10 == 10; 10 != 9;
        \\"foo-bar?!@";
        \\"Hello, World!";
        \\[1, 2];
    ;

    const expected = [_]Token{
        Token{ .type = TokenType.VAR, .literal = "var" },
        Token{ .type = TokenType.IDENT, .literal = "my_number" },
        Token{ .type = TokenType.ASSIGN, .literal = "=" },
        Token{ .type = TokenType.INT, .literal = "1" },
        Token{ .type = TokenType.PLUS, .literal = "+" },
        Token{ .type = TokenType.INT, .literal = "20" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.FN, .literal = "fn" },
        Token{ .type = TokenType.IDENT, .literal = "my_func" },
        Token{ .type = TokenType.LPAREN, .literal = "(" },
        Token{ .type = TokenType.IDENT, .literal = "number" },
        Token{ .type = TokenType.RPAREN, .literal = ")" },
        Token{ .type = TokenType.COLON, .literal = ":" },
        Token{ .type = TokenType.RET, .literal = "ret" },
        Token{ .type = TokenType.IDENT, .literal = "number" },
        Token{ .type = TokenType.PLUS, .literal = "+" },
        Token{ .type = TokenType.INT, .literal = "1" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },
        Token{ .type = TokenType.END, .literal = "end" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.VAR, .literal = "var" },
        Token{ .type = TokenType.IDENT, .literal = "other" },
        Token{ .type = TokenType.ASSIGN, .literal = "=" },
        Token{ .type = TokenType.IDENT, .literal = "my_func" },
        Token{ .type = TokenType.LPAREN, .literal = "(" },
        Token{ .type = TokenType.INT, .literal = "4" },
        Token{ .type = TokenType.RPAREN, .literal = ")" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.BANG, .literal = "!" },
        Token{ .type = TokenType.MINUS, .literal = "-" },
        Token{ .type = TokenType.SLASH, .literal = "/" },
        Token{ .type = TokenType.ASTERISK, .literal = "*" },
        Token{ .type = TokenType.INT, .literal = "5" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.INT, .literal = "5" },
        Token{ .type = TokenType.LT, .literal = "<" },
        Token{ .type = TokenType.INT, .literal = "10" },
        Token{ .type = TokenType.GT, .literal = ">" },
        Token{ .type = TokenType.INT, .literal = "5" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.IF, .literal = "if" },
        Token{ .type = TokenType.INT, .literal = "5" },
        Token{ .type = TokenType.LT, .literal = "<" },
        Token{ .type = TokenType.INT, .literal = "10" },
        Token{ .type = TokenType.COLON, .literal = ":" },

        Token{ .type = TokenType.RET, .literal = "ret" },
        Token{ .type = TokenType.TRUE, .literal = "true" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.ELSE, .literal = "else" },
        Token{ .type = TokenType.COLON, .literal = ":" },
        Token{ .type = TokenType.RET, .literal = "ret" },
        Token{ .type = TokenType.FALSE, .literal = "false" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },
        Token{ .type = TokenType.END, .literal = "end" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.INT, .literal = "10" },
        Token{ .type = TokenType.EQ, .literal = "==" },
        Token{ .type = TokenType.INT, .literal = "10" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },
        Token{ .type = TokenType.INT, .literal = "10" },
        Token{ .type = TokenType.NOT_EQ, .literal = "!=" },
        Token{ .type = TokenType.INT, .literal = "9" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.STRING, .literal = "foo-bar?!@" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },
        Token{ .type = TokenType.STRING, .literal = "Hello, World!" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.LBRACK, .literal = "[" },
        Token{ .type = TokenType.INT, .literal = "1" },
        Token{ .type = TokenType.COMMA, .literal = "," },
        Token{ .type = TokenType.INT, .literal = "2" },
        Token{ .type = TokenType.RBRACK, .literal = "]" },
        Token{ .type = TokenType.SEMICOLON, .literal = ";" },

        Token{ .type = TokenType.EOF, .literal = "EOF" },
    };

    var lexer = Lexer.init(input);
    for (expected) |expect| {
        const token = lexer.next();
        try std.testing.expect(expect.type == token.type);

        const literal_eq = std.mem.eql(u8, expect.literal, token.literal);
        try std.testing.expect(literal_eq);
    }
}
