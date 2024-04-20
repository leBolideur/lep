const std = @import("std");

const TokenError = @import("../utils/errors.zig").TokenError;

pub const TokenType = enum {
    ILLEGAL,
    EOF,

    // Identifiers + literals
    IDENT,
    INT,

    STRING,

    // Operators
    ASSIGN,
    PLUS,
    MINUS,
    BANG,
    ASTERISK,
    SLASH,
    LT,
    GT,
    EQ,
    NOT_EQ,

    // Delimiters
    COMMA,
    SEMICOLON,
    COLON,
    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,
    LBRACK,
    RBRACK,

    // Keywords
    FN,
    VAR,
    END,
    RET,
    TRUE,
    FALSE,
    IF,
    ELSE,

    // TODO: Rename
    pub fn get_token_string(token_type: TokenType) ![]const u8 {
        const value = switch (token_type) {
            .FN => "fn",
            .VAR => "var",
            .END => "end",
            .RET => "ret",
            .TRUE => "true",
            .FALSE => "false",
            .IF => "if",
            .ELSE => "else",
            .SEMICOLON => ";",
            .LPAREN => "(",
            .RPAREN => ")",
            .LBRACK => "[",
            .RBRACK => "]",
            .LBRACE => "{",
            .RBRACE => "}",
            .ASSIGN => "=",
            .PLUS => "+",
            .MINUS => "-",
            .BANG => "!",
            .ASTERISK => "*",
            .SLASH => "/",
            .LT => "<",
            .GT => ">",
            .EQ => "==",
            .NOT_EQ => "!=",
            .ILLEGAL => "ILLEGAL",
            .EOF => "EOF",
            .IDENT => "IDENT",
            .INT => "INT",
            .STRING => "STRING",
            .COLON => ":",
            .COMMA => ",",
        };

        return value;
    }

    pub fn get_keyword_from_str(str: []const u8) ?TokenType {
        if (std.mem.eql(u8, str, "fn")) {
            return TokenType.FN;
        } else if (std.mem.eql(u8, str, "var")) {
            return TokenType.VAR;
        } else if (std.mem.eql(u8, str, "end")) {
            return TokenType.END;
        } else if (std.mem.eql(u8, str, "ret")) {
            return TokenType.RET;
        } else if (std.mem.eql(u8, str, "true")) {
            return TokenType.TRUE;
        } else if (std.mem.eql(u8, str, "false")) {
            return TokenType.FALSE;
        } else if (std.mem.eql(u8, str, "if")) {
            return TokenType.IF;
        } else if (std.mem.eql(u8, str, "else")) {
            return TokenType.ELSE;
        }
        return null;
    }

    pub fn is_keyword(token_type: TokenType) bool {
        return switch (token_type) {
            TokenType.FN,
            TokenType.VAR,
            TokenType.END,
            TokenType.RET,
            TokenType.TRUE,
            TokenType.FALSE,
            TokenType.IF,
            TokenType.ELSE,
            => true,
            else => false,
        };
    }
};

pub const Token = struct {
    type: TokenType = undefined,
    literal: []const u8 = undefined,

    filepath: []const u8 = "repl",
    line: usize = 1,
    col: usize = undefined,

    pub fn lookup_ident(ident: []const u8) TokenType {
        const keyword = TokenType.get_keyword_from_str(ident);
        return keyword orelse TokenType.IDENT;
    }

    pub fn get_str(self: Token) ![]const u8 {
        return TokenType.get_token_string(self.type) catch return self.literal;
    }
};
