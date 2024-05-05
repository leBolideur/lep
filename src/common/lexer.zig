const std = @import("std");

const interpreter = @import("interpreter");

const token_import = interpreter.token;
const Token = token_import.Token;
const TokenType = token_import.TokenType;

const stdout = std.io.getStdIn().writer();

pub const Lexer = struct {
    input: []const u8,
    position: usize = 0,
    read_position: usize = 0,
    current_char: u8 = undefined,

    // Token position
    line: usize = 0,
    col: usize = 0,

    pub fn init(input: []const u8) Lexer {
        var lexer = Lexer{
            .input = input,
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
        self.col += 1;
    }

    fn peek_char(self: *Lexer) u8 {
        if (self.read_position >= self.input.len) {
            return 0;
        }

        return self.input[self.read_position];
    }

    fn new_token(self: Lexer, type_: TokenType, literal: []const u8) Token {
        const col = if (type_ == TokenType.EOF) 0 else self.col - literal.len;
        return Token{
            .type = type_,
            .literal = literal,
            .line = self.line + 1,
            .col = col,
        };
    }

    pub fn next(self: *Lexer) Token {
        var token: Token = undefined;

        self.skip_whitespaces();

        switch (self.current_char) {
            ';' => token = self.new_token(TokenType.SEMICOLON, ";"),
            ',' => token = self.new_token(TokenType.COMMA, ","),

            '"' => {
                self.read_char();
                const string = self.read_string();
                token = self.new_token(TokenType.STRING, string);
            },

            '=' => {
                if (self.peek_char() == '=') {
                    self.read_char();
                    token = self.new_token(TokenType.EQ, "==");
                } else {
                    token = self.new_token(TokenType.ASSIGN, "=");
                }
            },
            '+' => token = self.new_token(TokenType.PLUS, "+"),
            '-' => token = self.new_token(TokenType.MINUS, "-"),
            '*' => token = self.new_token(TokenType.ASTERISK, "*"),
            '/' => token = self.new_token(TokenType.SLASH, "/"),

            ':' => token = self.new_token(TokenType.COLON, ":"),
            '(' => token = self.new_token(TokenType.LPAREN, "("),
            ')' => token = self.new_token(TokenType.RPAREN, ")"),
            '[' => token = self.new_token(TokenType.LBRACK, "["),
            ']' => token = self.new_token(TokenType.RBRACK, "]"),
            '{' => token = self.new_token(TokenType.LBRACE, "{"),
            '}' => token = self.new_token(TokenType.RBRACE, "}"),
            '!' => {
                if (self.peek_char() == '=') {
                    self.read_char();
                    token = self.new_token(TokenType.NOT_EQ, "!=");
                } else {
                    token = self.new_token(TokenType.BANG, "!");
                }
            },

            '<' => token = self.new_token(TokenType.LT, "<"),
            '>' => token = self.new_token(TokenType.GT, ">"),
            0 => token = self.new_token(TokenType.EOF, "EOF"),
            else => {
                if (self.is_letter(self.current_char)) {
                    const ident = self.read_identifier();
                    const token_type = Token.lookup_ident(ident);
                    if (token_type != TokenType.IDENT) {
                        token = self.new_token(token_type, ident);
                        return token;
                    }
                    token = self.new_token(TokenType.IDENT, ident);
                    return token;
                } else if (std.ascii.isDigit(self.current_char)) {
                    const digit = self.read_digit();
                    token = self.new_token(TokenType.INT, digit);
                    return token;
                } else {
                    token = self.new_token(TokenType.ILLEGAL, "ILLEGAL");
                    return token;
                }
            },
        }

        self.read_char();

        return token;
    }

    fn is_letter(_: Lexer, char: u8) bool {
        return std.ascii.isAlphabetic(char) or char == '_';
    }

    fn read_identifier(self: *Lexer) []const u8 {
        const start_pos = self.position;
        while (self.is_letter(self.current_char)) self.read_char();

        return self.input[start_pos..self.position];
    }

    fn read_string(self: *Lexer) []const u8 {
        const start_pos = self.position;
        while (true) {
            self.read_char();
            if (self.current_char == '"' or self.current_char == '0') break;
        }

        return self.input[start_pos..self.position];
    }

    fn read_digit(self: *Lexer) []const u8 {
        const start_pos = self.position;
        while (std.ascii.isDigit(self.current_char)) self.read_char();

        return self.input[start_pos..self.position];
    }

    fn skip_whitespaces(self: *Lexer) void {
        while (std.ascii.isWhitespace(self.current_char)) {
            if (self.current_char == '\n') {
                self.line += 1;
                self.col = 0;
            }

            self.read_char();
        }
    }
};

test "test the lexer" {
    const input =
        // 22
        \\var my_number = 1 + 20;
        // 19
        \\fn my_func(number):
        // 15
        \\ret number + 1;
        // 4
        \\end;
        // 23
        \\var other = my_func(4);
        // 6
        \\!-/*5;
        // 11
        \\5 < 10 > 5;
        // 10
        \\if 5 < 10:
        // 9
        \\ret true;
        // 5
        \\else:
        // 10
        \\ret false;
        // 4
        \\end;
        // 17
        \\10 == 10; 10 != 9;
        // 13
        \\"foo-bar?!@";
        // 16
        \\"Hello, World!";
        // 7
        \\[1, 2];

        // 202
    ;

    const expected = [_]Token{
        Token{ .type = TokenType.VAR, .literal = "var", .line = 1, .col = 1 },
        Token{ .type = TokenType.IDENT, .literal = "my_number", .line = 1, .col = 5 },
        Token{ .type = TokenType.ASSIGN, .literal = "=", .line = 1, .col = 14 },
        Token{ .type = TokenType.INT, .literal = "1", .line = 1, .col = 17 },
        Token{ .type = TokenType.PLUS, .literal = "+", .line = 1, .col = 18 },
        Token{ .type = TokenType.INT, .literal = "20", .line = 1, .col = 21 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 1, .col = 22 },

        Token{ .type = TokenType.FN, .literal = "fn", .line = 2, .col = 1 },
        Token{ .type = TokenType.IDENT, .literal = "my_func", .line = 2, .col = 4 },
        Token{ .type = TokenType.LPAREN, .literal = "(", .line = 2, .col = 10 },
        Token{ .type = TokenType.IDENT, .literal = "number", .line = 2, .col = 12 },
        Token{ .type = TokenType.RPAREN, .literal = ")", .line = 2, .col = 17 },
        Token{ .type = TokenType.COLON, .literal = ":", .line = 2, .col = 18 },

        Token{ .type = TokenType.RET, .literal = "ret", .line = 3, .col = 1 },
        Token{ .type = TokenType.IDENT, .literal = "number", .line = 3, .col = 5 },
        Token{ .type = TokenType.PLUS, .literal = "+", .line = 3, .col = 11 },
        Token{ .type = TokenType.INT, .literal = "1", .line = 3, .col = 14 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 3, .col = 14 },

        Token{ .type = TokenType.END, .literal = "end", .line = 4, .col = 1 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 4, .col = 3 },

        Token{ .type = TokenType.VAR, .literal = "var", .line = 5, .col = 1 },
        Token{ .type = TokenType.IDENT, .literal = "other", .line = 5, .col = 5 },
        Token{ .type = TokenType.ASSIGN, .literal = "=", .line = 5, .col = 10 },
        Token{ .type = TokenType.IDENT, .literal = "my_func", .line = 5, .col = 13 },
        Token{ .type = TokenType.LPAREN, .literal = "(", .line = 5, .col = 19 },
        Token{ .type = TokenType.INT, .literal = "4", .line = 5, .col = 21 },
        Token{ .type = TokenType.RPAREN, .literal = ")", .line = 5, .col = 21 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 5, .col = 22 },

        Token{ .type = TokenType.BANG, .literal = "!", .line = 6, .col = 0 },
        Token{ .type = TokenType.MINUS, .literal = "-", .line = 6, .col = 1 },
        Token{ .type = TokenType.SLASH, .literal = "/", .line = 6, .col = 2 },
        Token{ .type = TokenType.ASTERISK, .literal = "*", .line = 6, .col = 3 },
        Token{ .type = TokenType.INT, .literal = "5", .line = 6, .col = 5 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 6, .col = 5 },

        Token{ .type = TokenType.INT, .literal = "5", .line = 7, .col = 1 },
        Token{ .type = TokenType.LT, .literal = "<", .line = 7, .col = 2 },
        Token{ .type = TokenType.INT, .literal = "10", .line = 7, .col = 5 },
        Token{ .type = TokenType.GT, .literal = ">", .line = 7, .col = 7 },
        Token{ .type = TokenType.INT, .literal = "5", .line = 7, .col = 10 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 7, .col = 10 },

        Token{ .type = TokenType.IF, .literal = "if", .line = 8, .col = 1 },
        Token{ .type = TokenType.INT, .literal = "5", .line = 8, .col = 4 },
        Token{ .type = TokenType.LT, .literal = "<", .line = 8, .col = 5 },
        Token{ .type = TokenType.INT, .literal = "10", .line = 8, .col = 8 },
        Token{ .type = TokenType.COLON, .literal = ":", .line = 8, .col = 9 },

        Token{ .type = TokenType.RET, .literal = "ret", .line = 9, .col = 1 },
        Token{ .type = TokenType.TRUE, .literal = "true", .line = 9, .col = 5 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 9, .col = 8 },

        Token{ .type = TokenType.ELSE, .literal = "else", .line = 10, .col = 1 },
        Token{ .type = TokenType.COLON, .literal = ":", .line = 10, .col = 4 },

        Token{ .type = TokenType.RET, .literal = "ret", .line = 11, .col = 1 },
        Token{ .type = TokenType.FALSE, .literal = "false", .line = 11, .col = 5 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 11, .col = 9 },

        Token{ .type = TokenType.END, .literal = "end", .line = 12, .col = 1 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 12, .col = 3 },

        Token{ .type = TokenType.INT, .literal = "10", .line = 13, .col = 1 },
        Token{ .type = TokenType.EQ, .literal = "==", .line = 13, .col = 3 },
        Token{ .type = TokenType.INT, .literal = "10", .line = 13, .col = 7 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 13, .col = 8 },
        Token{ .type = TokenType.INT, .literal = "10", .line = 13, .col = 11 },
        Token{ .type = TokenType.NOT_EQ, .literal = "!=", .line = 13, .col = 13 },
        Token{ .type = TokenType.INT, .literal = "9", .line = 13, .col = 17 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 13, .col = 17 },

        Token{ .type = TokenType.STRING, .literal = "foo-bar?!@", .line = 14, .col = 2 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 14, .col = 12 },

        Token{ .type = TokenType.STRING, .literal = "Hello, World!", .line = 15, .col = 2 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 15, .col = 15 },

        Token{ .type = TokenType.LBRACK, .literal = "[", .line = 16, .col = 0 },
        Token{ .type = TokenType.INT, .literal = "1", .line = 16, .col = 2 },
        Token{ .type = TokenType.COMMA, .literal = ",", .line = 16, .col = 2 },
        Token{ .type = TokenType.INT, .literal = "2", .line = 16, .col = 5 },
        Token{ .type = TokenType.RBRACK, .literal = "]", .line = 16, .col = 5 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 16, .col = 6 },

        Token{ .type = TokenType.EOF, .literal = "EOF", .line = 16, .col = 0 },
    };

    var lexer = Lexer.init(input);
    for (expected) |expect| {
        const token = lexer.next();
        try std.testing.expect(expect.type == token.type);

        const literal_eq = std.mem.eql(u8, expect.literal, token.literal);
        try std.testing.expect(literal_eq);

        try std.testing.expectEqual(expect.line, token.line);
        try std.testing.expectEqual(expect.col, token.col);
    }
}
