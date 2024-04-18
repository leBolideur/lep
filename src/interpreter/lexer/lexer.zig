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

    // Token position
    line: u32 = 1,
    token_start: usize = 0,
    token_end: usize = 0,
    total_pos_count: usize = 0,

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
            self.token_end += 1;
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

    fn new_token(self: Lexer, type_: TokenType, literal: []const u8) Token {
        var end_pos = self.token_end;
        if (self.current_char == ' ') end_pos -= 1;
        return Token{
            .type = type_,
            .literal = literal,
            .line = self.line,
            .start_pos = self.token_start,
            .end_pos = end_pos,
        };
    }

    pub fn next(self: *Lexer) Token {
        var token: Token = undefined;

        self.skip_whitespaces();

        self.token_start = self.read_position - self.total_pos_count;

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

        std.debug.print("token {s} @ {d}-{d}\n", .{ token.literal, token.start_pos, token.end_pos });
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
                self.total_pos_count += self.token_end;
                self.token_end = 0;
                self.token_start = 0;
                std.debug.print("last line len: {d}\n", .{self.total_pos_count});
            }
            self.read_char();
        }
    }
};

test "test the lexer" {
    const input =
        // 23
        \\var my_number = 1 + 20;
        // 19
        \\fn my_func(number):
        // 15
        \\ret number + 1;
        // 4
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
        Token{ .type = TokenType.VAR, .literal = "var", .line = 1, .start_pos = 1, .end_pos = 3 },
        Token{ .type = TokenType.IDENT, .literal = "my_number", .line = 1, .start_pos = 5, .end_pos = 13 },
        Token{ .type = TokenType.ASSIGN, .literal = "=", .line = 1, .start_pos = 15, .end_pos = 15 },
        Token{ .type = TokenType.INT, .literal = "1", .line = 1, .start_pos = 17, .end_pos = 17 },
        Token{ .type = TokenType.PLUS, .literal = "+", .line = 1, .start_pos = 19, .end_pos = 19 },
        Token{ .type = TokenType.INT, .literal = "20", .line = 1, .start_pos = 21, .end_pos = 23 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 1, .start_pos = 23, .end_pos = 23 },

        Token{ .type = TokenType.FN, .literal = "fn", .line = 2, .start_pos = 1, .end_pos = 2 },
        Token{ .type = TokenType.IDENT, .literal = "my_func", .line = 2, .start_pos = 4, .end_pos = 11 },
        Token{ .type = TokenType.LPAREN, .literal = "(", .line = 2, .start_pos = 11, .end_pos = 11 },
        Token{ .type = TokenType.IDENT, .literal = "number", .line = 2, .start_pos = 12, .end_pos = 18 },
        Token{ .type = TokenType.RPAREN, .literal = ")", .line = 2, .start_pos = 18, .end_pos = 18 },
        Token{ .type = TokenType.COLON, .literal = ":", .line = 2, .start_pos = 19, .end_pos = 19 },

        Token{ .type = TokenType.RET, .literal = "ret", .line = 3, .start_pos = 1, .end_pos = 3 },
        Token{ .type = TokenType.IDENT, .literal = "number", .line = 3, .start_pos = 5, .end_pos = 10 },
        Token{ .type = TokenType.PLUS, .literal = "+", .line = 3, .start_pos = 12, .end_pos = 12 },
        Token{ .type = TokenType.INT, .literal = "1", .line = 3, .start_pos = 14, .end_pos = 14 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 3, .start_pos = 15, .end_pos = 15 },

        Token{ .type = TokenType.END, .literal = "end", .line = 4, .start_pos = 0, .end_pos = 3 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 4, .start_pos = 4, .end_pos = 4 },

        Token{ .type = TokenType.VAR, .literal = "var", .line = 3, .start_pos = 0 },
        Token{ .type = TokenType.IDENT, .literal = "other", .line = 3, .start_pos = 0 },
        Token{ .type = TokenType.ASSIGN, .literal = "=", .line = 3, .start_pos = 0 },
        Token{ .type = TokenType.IDENT, .literal = "my_func", .line = 3, .start_pos = 0 },
        Token{ .type = TokenType.LPAREN, .literal = "(", .line = 3, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "4", .line = 3, .start_pos = 0 },
        Token{ .type = TokenType.RPAREN, .literal = ")", .line = 3, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 3, .start_pos = 0 },

        Token{ .type = TokenType.BANG, .literal = "!", .line = 4, .start_pos = 0 },
        Token{ .type = TokenType.MINUS, .literal = "-", .line = 4, .start_pos = 0 },
        Token{ .type = TokenType.SLASH, .literal = "/", .line = 4, .start_pos = 0 },
        Token{ .type = TokenType.ASTERISK, .literal = "*", .line = 4, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "5", .line = 4, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 4, .start_pos = 0 },

        Token{ .type = TokenType.INT, .literal = "5", .line = 5, .start_pos = 0 },
        Token{ .type = TokenType.LT, .literal = "<", .line = 5, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "10", .line = 5, .start_pos = 0 },
        Token{ .type = TokenType.GT, .literal = ">", .line = 5, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "5", .line = 5, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 5, .start_pos = 0 },

        Token{ .type = TokenType.IF, .literal = "if", .line = 6, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "5", .line = 6, .start_pos = 0 },
        Token{ .type = TokenType.LT, .literal = "<", .line = 6, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "10", .line = 6, .start_pos = 0 },
        Token{ .type = TokenType.COLON, .literal = ":", .line = 6, .start_pos = 0 },

        Token{ .type = TokenType.RET, .literal = "ret", .line = 7, .start_pos = 0 },
        Token{ .type = TokenType.TRUE, .literal = "true", .line = 7, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 7, .start_pos = 0 },

        Token{ .type = TokenType.ELSE, .literal = "else", .line = 8, .start_pos = 0 },
        Token{ .type = TokenType.COLON, .literal = ":", .line = 8, .start_pos = 0 },
        Token{ .type = TokenType.RET, .literal = "ret", .line = 8, .start_pos = 0 },
        Token{ .type = TokenType.FALSE, .literal = "false", .line = 8, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 8, .start_pos = 0 },
        Token{ .type = TokenType.END, .literal = "end", .line = 8, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 8, .start_pos = 0 },

        Token{ .type = TokenType.INT, .literal = "10", .line = 9, .start_pos = 0 },
        Token{ .type = TokenType.EQ, .literal = "==", .line = 9, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "10", .line = 9, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 9, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "10", .line = 9, .start_pos = 0 },
        Token{ .type = TokenType.NOT_EQ, .literal = "!=", .line = 9, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "9", .line = 9, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 9, .start_pos = 0 },

        Token{ .type = TokenType.STRING, .literal = "foo-bar?!@", .line = 10, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 10, .start_pos = 0 },
        Token{ .type = TokenType.STRING, .literal = "Hello, World!", .line = 10, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 10, .start_pos = 0 },

        Token{ .type = TokenType.LBRACK, .literal = "[", .line = 11, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "1", .line = 11, .start_pos = 0 },
        Token{ .type = TokenType.COMMA, .literal = ",", .line = 11, .start_pos = 0 },
        Token{ .type = TokenType.INT, .literal = "2", .line = 11, .start_pos = 0 },
        Token{ .type = TokenType.RBRACK, .literal = "]", .line = 11, .start_pos = 0 },
        Token{ .type = TokenType.SEMICOLON, .literal = ";", .line = 11, .start_pos = 0 },

        Token{ .type = TokenType.EOF, .literal = "EOF", .line = 12, .start_pos = 0 },
    };

    var lexer = Lexer.init(input);
    for (expected) |expect| {
        const token = lexer.next();
        try std.testing.expect(expect.type == token.type);

        const literal_eq = std.mem.eql(u8, expect.literal, token.literal);
        try std.testing.expect(literal_eq);

        try std.testing.expectEqual(expect.line, token.line);
        try std.testing.expectEqual(expect.start_pos, token.start_pos);
        try std.testing.expectEqual(expect.end_pos, token.end_pos);
    }
}
