const std = @import("std");

const repl = @import("interpreter/repl.zig");

const Lexer = @import("interpreter/lexer/lexer.zig").Lexer;
const TokenType = @import("interpreter/lexer/token.zig").TokenType;

const Parser = @import("interpreter/parser/parser.zig").Parser;

const Evaluator = @import("interpreter/eval/evaluator.zig").Evaluator;

const Environment = @import("interpreter/intern/environment.zig").Environment;

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

    _ = args.next();
    const filepath = args.next().?;
    const file = std.fs.cwd().openFile(filepath, .{ .mode = .read_only }) catch |err| {
        try stderr.print("Error loading file: {!}\n", .{err});
        return;
    };

    const stat = try file.stat();
    var reader = file.reader();
    var buffer = try alloc.alloc(u8, stat.size);
    _ = try reader.readAll(buffer);

    var env = try Environment.init(&alloc);

    var lexer = Lexer.init(buffer);
    var parser = try Parser.init(&lexer, &alloc);
    const program = try parser.parse();

    const evaluator = try Evaluator.init(&alloc);
    const object = try evaluator.eval(program, &env);

    var buf = std.ArrayList(u8).init(alloc);
    try object.inspect(&buf);
    switch (object.*) {
        .err => try stderr.print("error > {s}\n", .{try buf.toOwnedSlice()}),
        .null => {},
        else => try stdout.print("{s}\n", .{try buf.toOwnedSlice()}),
    }
}
