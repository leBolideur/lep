const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("token.zig").TokenType;

pub fn repl() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    while (true) {
        var input: [50]u8 = undefined;

        try stdout.print("\n>> ", .{});
        const ret = try stdin.read(&input);

        if (ret == 1) break;

        var lexer = Lexer.init(input[0..ret]);
        while (true) {
            const token = lexer.next();
            try stdout.print("\n{?}", .{token});
            if (token.type == TokenType.EOF) break;
        }
    }
}
