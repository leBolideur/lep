const std = @import("std");

const interpreter = @import("interpreter");
const common = @import("common");
const compiler_ = @import("compiler");

const Lexer = common.lexer.Lexer;
const TokenType = interpreter.token.TokenType;

const Parser = common.parser.Parser;

const Evaluator = interpreter.evaluator.Evaluator;

const Environment = interpreter.environment.Environment;

const Compiler = compiler_.compiler.Compiler;
const VM = compiler_.vm.VM;

const Object = common.object.Object;

pub fn repl(alloc: *const std.mem.Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    // const stderr = std.io.getStdErr().writer();

    // var env = try Environment.init(alloc);
    var constants = std.ArrayList(*const Object).init(alloc.*);
    const globals = try alloc.alloc(*const Object, 1024);
    const symtab = try compiler_.symbol_table.SymbolTable.new(alloc);

    while (true) {
        var input: [1000]u8 = undefined;

        try stdout.print("\n>> ", .{});
        const ret = try stdin.read(&input);

        if (ret == 1) break;

        var lexer = Lexer.init(input[0..ret]);
        var parser = try Parser.init(&lexer, alloc);
        const program = try parser.parse();

        // const evaluator = try Evaluator.init(alloc);
        // const object = try evaluator.eval(program, &env);

        var compiler = try Compiler.init_with_state(alloc, symtab, constants);
        try compiler.compile(program);

        const bytecode = compiler.get_bytecode();
        constants = bytecode.constants;
        var vm = try VM.new_with_globals(alloc, bytecode, globals);
        // TODO: Erros handling here
        _ = try vm.run();
        const object = vm.last_popped_element();

        var buf = std.ArrayList(u8).init(alloc.*);
        try object.?.inspect(&buf);
        try stdout.print("{s}\n", .{try buf.toOwnedSlice()});

        // switch (object.?) {
        //     .err => try stderr.print("error > {s}\n", .{try buf.toOwnedSlice()}),
        //     .null => {},
        //     else => try stdout.print("{s}\n", .{try buf.toOwnedSlice()}),
        // }
    }
}
