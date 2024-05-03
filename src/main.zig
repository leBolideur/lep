const std = @import("std");

const interpreter = @import("interpreter");
const common = @import("common");
const compiler_ = @import("compiler");

const Compiler = compiler_.compiler.Compiler;
const VM = compiler_.vm.VM;

const repl = @import("repl.zig");

const Lexer = common.lexer.Lexer;

const Parser = common.parser.Parser;

const Evaluator = interpreter.evaluator.Evaluator;

const Environment = interpreter.environment.Environment;

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
    const buffer = try alloc.alloc(u8, stat.size);
    _ = try reader.readAll(buffer);

    // var env = try Environment.init(&alloc);

    var lexer = Lexer.init(buffer);
    var parser = try Parser.init(&lexer, &alloc);
    const program = try parser.parse();

    // const evaluator = try Evaluator.init(&alloc);
    // const object = try evaluator.eval(program, &env);

    var compiler = try Compiler.init(&alloc);
    try compiler.compile(program);
    var vm = try VM.new(&alloc, compiler.get_bytecode());
    _ = try vm.run();
    const object = vm.last_popped_element();

    var buf = std.ArrayList(u8).init(alloc);
    try object.?.inspect(&buf);
    switch (object.?.*) {
        .err => try stderr.print("error > {s}\n", .{try buf.toOwnedSlice()}),
        .null => {},
        else => try stdout.print("{s}\n", .{try buf.toOwnedSlice()}),
    }
}
