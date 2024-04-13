const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("token.zig").TokenType;

const Parser = @import("parser.zig").Parser;

const Evaluator = @import("evaluator.zig").Evaluator;

pub fn repl() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    while (true) {
        var input: [50]u8 = undefined;

        try stdout.print("\n>> ", .{});
        const ret = try stdin.read(&input);

        if (ret == 1) break;

        var lexer = Lexer.init(input[0..ret]);
        var parser = try Parser.init(&lexer, &alloc);
        const program = try parser.parse();

        const evaluator = try Evaluator.init(&alloc);
        const object = try evaluator.eval(program);

        // var buf = std.ArrayList(u8).init(alloc);
        // defer buf.deinit();

        // const str = try program.debug_string(&buf);
        // try stdout.print("{s}\n", .{str});

        object.inspect();
    }
}
