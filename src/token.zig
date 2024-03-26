const std = @import("std");

const Keyword = enum { FN, VAR, END, RET };
const Delimiter = enum { COMMA, SEMICOLON, COLON, LPAREN, RPAREN };
const Operator = enum { ASSIGN, PLUS };
const Identifier = enum { IDENT };
const Literal = enum { INT };
const Misc = enum { ILLEGAL, EOF };

pub const TokenType = enum {
    ILLEGAL,
    EOF,

    // Identifiers + literals
    IDENT,
    INT,

    // Operators
    ASSIGN,
    PLUS,

    // Delimiters
    COMMA,
    SEMICOLON,
    COLON,
    LPAREN,
    RPAREN,
    // LBRACE = "{",
    // RBRACE = "}",

    // Keywords
    FN,
    VAR,
    END,
    RET,

    pub fn get_str_from_keyword(token_type: TokenType) ?[]const u8 {
        const value = switch (token_type) {
            TokenType.FN => "fn",
            TokenType.VAR => "var",
            TokenType.END => "end",
            TokenType.RET => "ret",
            else => null,
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
        }
        return null;
    }

    pub fn is_keyword(token_type: TokenType) bool {
        return switch (token_type) {
            TokenType.FN => true,
            TokenType.VAR => true,
            TokenType.END => true,
            TokenType.RET => true,
            else => false,
        };
    }
};

pub const Token = struct {
    type: TokenType = undefined,
    literal: []const u8 = undefined,

    // filepath: []const u8,
    // line: u32,

    pub fn lookup_ident(ident: []const u8) TokenType {
        const keyword = TokenType.get_keyword_from_str(ident);
        return keyword orelse TokenType.IDENT;
    }
};
