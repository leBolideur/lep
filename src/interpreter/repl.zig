const std = @import("std");

const Lexer = @import("lexer/lexer.zig").Lexer;
const TokenType = @import("lexer/token.zig").TokenType;

const Parser = @import("parser/parser.zig").Parser;

const Evaluator = @import("eval/evaluator.zig").Evaluator;

const Environment = @import("intern/environment.zig").Environment;

pub fn repl(alloc: *const std.mem.Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // var alloc = arena.allocator();

    var env = try Environment.init(alloc);

    while (true) {
        var input: [1000]u8 = undefined;

        try stdout.print("\n>> ", .{});
        const ret = try stdin.read(&input);

        if (ret == 1) break;

        var lexer = Lexer.init(input[0..ret]);
        var parser = try Parser.init(&lexer, alloc);
        const program = try parser.parse();

        const evaluator = try Evaluator.init(alloc);
        const object = try evaluator.eval(program, &env);

        var buf = std.ArrayList(u8).init(alloc.*);
        try object.inspect(&buf);
        switch (object.*) {
            .err => try stderr.print("error > {s}\n", .{try buf.toOwnedSlice()}),
            else => try stdout.print("{s}\n", .{try buf.toOwnedSlice()}),
        }
    }
}
