const std = @import("std");

const token_import = @import("token.zig");
const Token = token_import.Token;
const TokenType = token_import.TokenType;

const stdout = std.io.getStdIn().writer();

pub const Lexer = struct {
    input: []const u8,
    position: usize = 0,
    read_position: usize = 0,
    current_char: u8 = undefined,

    pub fn init(input: []const u8) Lexer {
        var lexer = Lexer{
            .input = input,
            // .position = undefined,
            // .read_position = undefined,
            // .current_char = undefined,
        };

        lexer.read_char();

        return lexer;
    }

    fn read_char(self: *Lexer) void {
        if (self.read_position >= self.input.len) {
            self.current_char = 0;
        } else {
            self.current_char = self.input[self.read_position];
        }

        self.position = self.read_position;
        self.read_position += 1;
    }

    fn peek_char(self: *Lexer) u8 {
        if (self.read_position >= self.input.len) {
            return 0;
        }

        return self.input[self.read_position];
    }

    pub fn next(self: *Lexer) Token {
        var token: Token = undefined;

        self.skip_whitespaces();

        // std.debug.print("\n >> current char: {c}\n", .{self.current_char});
        switch (self.current_char) {
            ';' => token = Token{ .type = TokenType.SEMICOLON, .literal = ";" },
            ',' => token = Token{ .type = TokenType.COMMA, .literal = "," },

            '=' => {
                if (self.peek_char() == '=') {
                    self.read_char();
                    token = Token{ .type = TokenType.EQ, .literal = "==" };
                } else {
                    token = Token{ .type = TokenType.ASSIGN, .literal = "=" };
                }
            },
            '+' => token = Token{ .type = TokenType.PLUS, .literal = "+" },
            '-' => token = Token{ .type = TokenType.MINUS, .literal = "-" },
            '*' => token = Token{ .type = TokenType.ASTERISK, .literal = "*" },
            '/' => token = Token{ .type = TokenType.SLASH, .literal = "/" },

            ':' => token = Token{ .type = TokenType.COLON, .literal = ":" },
            '(' => token = Token{ .type = TokenType.LPAREN, .literal = "(" },
            ')' => token = Token{ .type = TokenType.RPAREN, .literal = ")" },
            '!' => {
                if (self.peek_char() == '=') {
                    self.read_char();
                    token = Token{ .type = TokenType.NOT_EQ, .literal = "!=" };
                } else {
                    token = Token{ .type = TokenType.BANG, .literal = "!" };
                }
            },

            '<' => token = Token{ .type = TokenType.LT, .literal = "<" },
            '>' => token = Token{ .type = TokenType.GT, .literal = ">" },
            0 => token = Token{ .type = TokenType.EOF, .literal = "EOF" },
            else => {
                if (self.is_letter(self.current_char)) {
                    const ident = self.read_identifier();
                    const token_type = Token.lookup_ident(ident);
                    if (token_type != TokenType.IDENT) {
                        const keyword = TokenType.get_keyword_from_str(ident);
                        token = Token{ .type = keyword.?, .literal = ident };
                        return token;
                    } else {
                        token = Token{ .type = TokenType.IDENT, .literal = ident };
                        return token;
                    }
                } else if (std.ascii.isDigit(self.current_char)) {
                    const digit = self.read_digit();
                    token = Token{ .type = TokenType.INT, .literal = digit };
                    return token;
                } else {
                    token = Token{ .type = TokenType.ILLEGAL, .literal = "ILLEGAL" };
                }
            },
        }

        self.read_char();

        return token;
    }

    fn is_letter(self: Lexer, char: u8) bool {
        _ = self;
        return std.ascii.isAlphabetic(char) or char == '_';
    }

    fn read_identifier(self: *Lexer) []const u8 {
        const start_pos = self.position;
        while (self.is_letter(self.current_char)) self.read_char();

        return self.input[start_pos..self.position];
    }

    fn read_digit(self: *Lexer) []const u8 {
        const start_pos = self.position;
        while (std.ascii.isDigit(self.current_char)) self.read_char();

        return self.input[start_pos..self.position];
    }

    fn skip_whitespaces(self: *Lexer) void {
        while (std.ascii.isWhitespace(self.current_char)) {
            self.read_char();
        }
    }
};

test "test the lexer" {
    const input =
        \\var my_number = 1 + 20;
        \\fn my_func(number):
        \\ret number + 1;
        \\end;
        \\var other = my_func(4);
        \\!-/*5;
        \\5 < 10 > 5;
        \\if 5 < 10:
        \\ ret true;
        \\ else:
        \\ ret false;
        \\end;
        \\10 == 10; 10 != 9;
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

        Token{ .type = TokenType.EOF, .literal = "EOF" },
    };

    var lexer = Lexer.init(input);
    for (expected) |expect| {
        const token = lexer.next();
        // std.debug.print("token: {?}\n", .{token});
        try std.testing.expect(expect.type == token.type);

        const literal_eq = std.mem.eql(u8, expect.literal, token.literal);
        try std.testing.expect(literal_eq);
    }
}
