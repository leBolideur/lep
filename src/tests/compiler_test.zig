const std = @import("std");

const common = @import("common");
const interpreter = @import("interpreter");
const compiler_ = @import("compiler");

const Lexer = common.lexer.Lexer;
const Parser = common.parser.Parser;
const Object = common.object.Object;
const ast = common.ast;

const Opcode = compiler_.opcode.Opcode;
const bytecode_ = compiler_.bytecode;

// const comp_imp = @import("compiler");
const Compiler = compiler_.compiler.Compiler;

test "Test the compiler with Integers arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const i64 }{
        .{
            "1 + 2;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpAdd, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 1, 2 },
        },
        .{
            "1 - 2;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpSub, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 1, 2 },
        },
        .{
            "2 * 3;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpMul, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 2, 3 },
        },
        .{
            "6 / 2;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpDiv, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 6, 2 },
        },
        .{
            "1; 2;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 1, 2 },
        },
        .{
            "-6;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpMinus, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{6},
        },
    };

    try run_test(&alloc, test_cases, i64);
}

test "Test the compiler with Boolean expressions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions
    const test_cases = [_]struct { []const u8, []const []const u8 }{
        .{
            "true;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpTrue, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
        },
        .{
            "false;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpFalse, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
        },
        .{
            "!false;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpFalse, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpBang, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
        },
    };

    try run_test(&alloc, test_cases, bool);
}

test "Test the compiler with Boolean Comparisons" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, [4][]const u8, [2]i64 }{
        .{
            "1 > 2;",
            [_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpGT, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            [2]i64{ 1, 2 },
        },
        .{
            "1 < 2;",
            [_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpGT, &[_]usize{}), // Code reordering
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            [2]i64{ 1, 2 },
        },
        .{
            "1 == 2;",
            [_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpEq, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            [2]i64{ 1, 2 },
        },
        .{
            "1 != 2;",
            [_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpNotEq, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            [2]i64{ 1, 2 },
        },
        // FIXME: To do... Think about how to handle generic tests
        // .{
        //     "true == false;",
        //     [_][]const u8{
        //         try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
        //         try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
        //         try bytecode_.make(&alloc, Opcode.OpGT, &[_]usize{}),
        //         try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
        //     },
        //     [2]i64{ 1, 2 },
        // },
    };

    try run_test(&alloc, test_cases, bool);
}

test "Test conditionals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const i64 }{
        .{
            "if (true): 10; end 666;",
            &[_][]const u8{
                // 0000
                try bytecode_.make(&alloc, Opcode.OpTrue, &[_]usize{}),
                // 0001
                try bytecode_.make(&alloc, Opcode.OpJumpNotTrue, &[_]usize{10}),
                // 0004
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                // 0007
                try bytecode_.make(&alloc, Opcode.OpJump, &[_]usize{11}),
                // 0010
                try bytecode_.make(&alloc, Opcode.OpNull, &[_]usize{}),
                // 0011 -- !Not a part of consequence! Conditionals are expression, evaluates to 10 here
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
                // 0012
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                // 0015
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 10, 666 },
        },
        .{
            "if (true): 10; else: 20; end 666;",
            &[_][]const u8{
                // 0000
                try bytecode_.make(&alloc, Opcode.OpTrue, &[_]usize{}),
                // 0001
                try bytecode_.make(&alloc, Opcode.OpJumpNotTrue, &[_]usize{10}),
                // 0004
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                // 0007
                try bytecode_.make(&alloc, Opcode.OpJump, &[_]usize{13}),
                // 0010
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                // 0013 -- ! Reason of pop here: Conditionals are expression, evaluates to 10 here
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
                // 0014
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                // 0017
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 10, 20, 666 },
        },
    };

    try run_test(&alloc, test_cases, null);
}

test "Test global var statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const i64 }{
        .{
            "var a = 6; var b = 12;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpSetGlobal, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpSetGlobal, &[_]usize{1}),
            },
            &[_]i64{ 6, 12 },
        },
        .{
            "var a = 6; a;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpSetGlobal, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpGetGlobal, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{6},
        },
        .{
            "var a = 6; var b = a; b;",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpSetGlobal, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpGetGlobal, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpSetGlobal, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpGetGlobal, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{6},
        },
    };

    try run_test(&alloc, test_cases, i64);
}

test "Test Strings litteral and expressions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const []const u8 }{
        .{
            \\"LEP";
            ,
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_][]const u8{"LEP"},
        },
        .{
            \\"Hello" + ", " + "World!";
            ,
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpAdd, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpAdd, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_][]const u8{ "Hello", ", ", "World!" },
        },
    };

    try run_test(&alloc, test_cases, []const u8);
}

fn run_test(alloc: *const std.mem.Allocator, test_cases: anytype, comptime type_: ?type) !void {
    for (test_cases) |exp| {
        const root_node = try parse(exp[0], alloc);
        var compiler = try Compiler.init(alloc);
        try compiler.compile(root_node);

        const bytecode = compiler.get_bytecode();
        try test_instructions(alloc, exp[1], bytecode.instructions);
        if (type_ == i64) {
            try test_integer_constants(exp[2], bytecode.constants);
        } else if (type_ == []const u8) {
            try test_string_constants(exp[2], bytecode.constants);
        }
    }
}

fn parse(input: []const u8, alloc: *const std.mem.Allocator) !ast.Node {
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, alloc);

    const root_node = try parser.parse();
    // FIXME: Should return a pointer?
    return root_node;
}

fn test_instructions(
    alloc: *const std.mem.Allocator,
    expected: anytype,
    actual: bytecode_.Instructions,
) !void {
    var flattened_ = std.ArrayList(u8).init(alloc.*);
    for (expected) |exp| {
        for (exp) |b| {
            try flattened_.append(b);
        }
    }

    const flattened = try flattened_.toOwnedSlice();

    try std.testing.expectEqual(flattened.len, actual.instructions.items.len);

    for (flattened, actual.instructions.items) |exp, act| {
        try std.testing.expectEqual(exp, act);
    }
}

fn test_integer_constants(expected: anytype, actual: std.ArrayList(*const Object)) !void {
    try std.testing.expectEqual(expected.len, actual.items.len);

    for (expected, actual.items) |exp, obj| {
        switch (obj.*) {
            .integer => |int| {
                try std.testing.expectEqual(exp, int.value);
            },
            else => |other| {
                std.debug.print("Object is not an Integer, got: {any}\n", .{other});
            },
        }
    }
}

fn test_string_constants(expected: anytype, actual: std.ArrayList(*const Object)) !void {
    try std.testing.expectEqual(expected.len, actual.items.len);

    for (expected, actual.items) |exp, obj| {
        switch (obj.*) {
            .string => |string| {
                try std.testing.expectEqualStrings(exp, string.value);
            },
            else => |other| {
                std.debug.print("Object is not a String, got: {any}\n", .{other});
            },
        }
    }
}
