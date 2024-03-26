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
        // std.debug.print("\nnext token: {c}", .{self.current_char});
    }

    pub fn next(self: *Lexer) Token {
        var token: Token = undefined;
        switch (self.current_char) {
            ';' => token = Token{ .type = TokenType.SEMICOLON, .literal = ";" },
            ',' => token = Token{ .type = TokenType.COMMA, .literal = "," },
            '=' => token = Token{ .type = TokenType.ASSIGN, .literal = "=" },
            '+' => token = Token{ .type = TokenType.PLUS, .literal = "+" },
            0 => token = Token{ .type = TokenType.EOF, .literal = "EOF" },
            else => {
                if (self.is_letter(self.current_char)) {
                    const ident = self.read_identifier();
                    const token_type = Token.lookup_ident(ident);
                    if (token_type != TokenType.IDENT) {
                        const keyword = TokenType.get_keyword_from_str(ident);
                        std.debug.print("keyword >>>> {?}\n", .{keyword});
                        token = Token{ .type = keyword.?, .literal = ident };
                    } else {
                        token = Token{ .type = TokenType.IDENT, .literal = ident };
                        std.debug.print("ident >>>> {s}\n", .{ident});
                    }
                } else {
                    token = Token{ .type = TokenType.ILLEGAL, .literal = "ILLEGAL" };
                }

                // std.debug.print("token >>>> {?}\t{s}\n", .{ token.type, token.literal });
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
};

test "test the lexer" {
    const input =
        \\var my_number = 1 + 2;
        // \\if my_number == 3:
        // \\else:
        \\fn my_func(number):
        \\ret number + 1;
        \\end;
        \\var other = my_func(4);
    ;

    const expected = [_]Token{
        Token{ .type = TokenType.VAR, .literal = "var" },
        Token{ .type = TokenType.IDENT, .literal = "my_number" },
        Token{ .type = TokenType.ASSIGN, .literal = "=" },
        Token{ .type = TokenType.INT, .literal = "1" },
        Token{ .type = TokenType.PLUS, .literal = "+" },
        Token{ .type = TokenType.INT, .literal = "2" },
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

        Token{ .type = TokenType.EOF, .literal = "EOF" },
    };

    var lexer = Lexer.init(input);
    for (expected) |expect| {
        const token = lexer.next();
        std.testing.expectEqual(expect.type, token.type) catch {
            // std.debug.print("incorrect TYPE. Expected: {?}, got: {?}\n", .{ expect.type, token.type });
        };
        std.testing.expectEqual(expect.literal, token.literal) catch {
            // std.debug.print("incorrect LITERAL. Expected: {s}, got: {s}\n", .{ expect.literal, token.literal });
        };
    }
}
