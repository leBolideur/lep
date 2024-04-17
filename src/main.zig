const std = @import("std");

const repl = @import("repl.zig");

const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("token.zig").TokenType;

const Parser = @import("parser.zig").Parser;

const Evaluator = @import("evaluator.zig").Evaluator;

const Environment = @import("environment.zig").Environment;

pub fn main() !void {
    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var args = std.process.args().inner;
    if (args.count == 1) {
        try repl.repl(&alloc);
        return;
    }

    const filepath = args.next().?;

    const file = std.fs.cwd().openFile(filepath, .{}) catch |err| {
        try stderr.print("Error loading file: {!}\n", .{err});
        return;
    };
    const reader = file.reader();
    const stat = try file.stat();
    const content = try reader.readAllAlloc(alloc, stat.size);

    var env = try Environment.init(&alloc);

    var lexer = Lexer.init(content);
    var parser = try Parser.init(&lexer, &alloc);
    const program = try parser.parse();

    const evaluator = try Evaluator.init(&alloc);
    const object = try evaluator.eval(program, &env);

    var buf = std.ArrayList(u8).init(alloc);
    try object.inspect(&buf);
    switch (object.*) {
        .err => try stderr.print("error > {s}\n", .{try buf.toOwnedSlice()}),
        else => try stdout.print("{s}\n", .{try buf.toOwnedSlice()}),
    }
}
