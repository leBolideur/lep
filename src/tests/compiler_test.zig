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

test "Test Array litteral with Integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const i64 }{
        .{
            "[];",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpArray, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{},
        },
        .{
            "[1, 2, 4];",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpArray, &[_]usize{3}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 1, 2, 4 },
        },
        .{
            "[1 + 2, 3 - 4, 5 * 6];",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpAdd, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{3}),
                try bytecode_.make(&alloc, Opcode.OpSub, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{4}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{5}),
                try bytecode_.make(&alloc, Opcode.OpMul, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpArray, &[_]usize{3}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 1, 2, 3, 4, 5, 6 },
        },
    };

    try run_test(&alloc, test_cases, i64);
}

const ExpectedHashConstant = union(enum) {
    string: []const u8,
    integer: i64,
};

test "Test Hash litteral with Integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants, string constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const ExpectedHashConstant }{
        .{
            "{};",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpHash, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedHashConstant{},
        },
        .{
            \\{"not_three": 4, "one": 1, "two": 2};
            ,
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{3}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{4}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{5}),
                try bytecode_.make(&alloc, Opcode.OpHash, &[_]usize{6}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedHashConstant{
                ExpectedHashConstant{ .string = "not_three" },
                ExpectedHashConstant{ .integer = 4 },
                ExpectedHashConstant{ .string = "one" },
                ExpectedHashConstant{ .integer = 1 },
                ExpectedHashConstant{ .string = "two" },
                ExpectedHashConstant{ .integer = 2 },
            },
        },
        // .{
        //     \\{"foo": 3 - 4, "bar": 5 * 6};
        //     ,
        //     &[_][]const u8{
        //         try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
        //         try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
        //         try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
        //         try bytecode_.make(&alloc, Opcode.OpSub, &[_]usize{}),
        //         try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{3}),
        //         try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{4}),
        //         try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{5}),
        //         try bytecode_.make(&alloc, Opcode.OpMul, &[_]usize{}),
        //         try bytecode_.make(&alloc, Opcode.OpHash, &[_]usize{4}),
        //         try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
        //     },
        //     &[_]ExpectedHashConstant{
        //         ExpectedHashConstant{ .string = "foo" },
        //         ExpectedHashConstant{ .integer = -1 },
        //         ExpectedHashConstant{ .string = "bar" },
        //         ExpectedHashConstant{ .integer = 30 },
        //     },
        // },
    };

    try run_test(&alloc, test_cases, ExpectedHashConstant);
}

test "Test Index expressions with Array" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const i64 }{
        .{
            "[1,2,3][1 + 1];",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpArray, &[_]usize{3}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{3}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{4}),
                try bytecode_.make(&alloc, Opcode.OpAdd, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpIndex, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]i64{ 1, 2, 3, 1, 1 },
        },
    };

    try run_test(&alloc, test_cases, i64);
}

test "Test Index expressions with Hash" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const ExpectedHashConstant }{
        .{
            \\{"foo": "bar"}[1 * 1];
            ,
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpHash, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{3}),
                try bytecode_.make(&alloc, Opcode.OpMul, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpIndex, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedHashConstant{
                ExpectedHashConstant{ .string = "foo" },
                ExpectedHashConstant{ .string = "bar" },
                ExpectedHashConstant{ .integer = 1 },
                ExpectedHashConstant{ .integer = 1 },
            },
        },
    };

    try run_test(&alloc, test_cases, ExpectedHashConstant);
}

const ExpectedFunctionConstants = union(enum) {
    int: i64,
    instructions: []const []const u8,
};

test "Test Functions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const ExpectedFunctionConstants }{
        .{
            "fn(): ret 5 + 10; end",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedFunctionConstants{
                ExpectedFunctionConstants{ .int = 5 },
                ExpectedFunctionConstants{ .int = 10 },
                ExpectedFunctionConstants{
                    .instructions = &[_][]const u8{
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                        try bytecode_.make(&alloc, Opcode.OpAdd, &[_]usize{}),
                        try bytecode_.make(&alloc, Opcode.OpReturnValue, &[_]usize{}),
                    },
                },
            },
        },
        .{
            "fn(): 10 + 6; end",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedFunctionConstants{
                ExpectedFunctionConstants{ .int = 10 },
                ExpectedFunctionConstants{ .int = 6 },
                ExpectedFunctionConstants{
                    .instructions = &[_][]const u8{
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                        try bytecode_.make(&alloc, Opcode.OpAdd, &[_]usize{}),
                        try bytecode_.make(&alloc, Opcode.OpReturnValue, &[_]usize{}),
                    },
                },
            },
        },
        .{
            "fn(): 10; 6; end",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedFunctionConstants{
                ExpectedFunctionConstants{ .int = 10 },
                ExpectedFunctionConstants{ .int = 6 },
                ExpectedFunctionConstants{
                    .instructions = &[_][]const u8{
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                        try bytecode_.make(&alloc, Opcode.OpReturnValue, &[_]usize{}),
                    },
                },
            },
        },
        .{
            "fn():  end",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedFunctionConstants{
                ExpectedFunctionConstants{
                    .instructions = &[_][]const u8{
                        try bytecode_.make(&alloc, Opcode.OpReturn, &[_]usize{}),
                    },
                },
            },
        },
    };

    try run_test(&alloc, test_cases, ExpectedFunctionConstants);
}

test "Test Functions local bindings" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const ExpectedFunctionConstants }{
        .{
            \\var num = 1;
            \\fn(): ret num; end
            ,
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpSetGlobal, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedFunctionConstants{
                ExpectedFunctionConstants{ .int = 1 },
                ExpectedFunctionConstants{
                    .instructions = &[_][]const u8{
                        try bytecode_.make(&alloc, Opcode.OpGetGlobal, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpReturnValue, &[_]usize{}),
                    },
                },
            },
        },
        .{
            \\fn(): 
            \\  var num = 10;
            \\  ret num; 
            \\end
            ,
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedFunctionConstants{
                ExpectedFunctionConstants{ .int = 10 },
                // ExpectedFunctionConstants{ .int = 6 },
                ExpectedFunctionConstants{
                    .instructions = &[_][]const u8{
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpSetLocal, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpGetLocal, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpReturnValue, &[_]usize{}),
                    },
                },
            },
        },
        .{
            \\fn(): 
            \\  var a = 10;
            \\  var b = 6;
            \\  a + b;
            \\end
            ,
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{2}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedFunctionConstants{
                ExpectedFunctionConstants{ .int = 10 },
                ExpectedFunctionConstants{ .int = 6 },
                ExpectedFunctionConstants{
                    .instructions = &[_][]const u8{
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpSetLocal, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                        try bytecode_.make(&alloc, Opcode.OpSetLocal, &[_]usize{1}),
                        try bytecode_.make(&alloc, Opcode.OpGetLocal, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpGetLocal, &[_]usize{1}),
                        try bytecode_.make(&alloc, Opcode.OpAdd, &[_]usize{}),
                        try bytecode_.make(&alloc, Opcode.OpReturnValue, &[_]usize{}),
                    },
                },
            },
        },
    };

    try run_test(&alloc, test_cases, ExpectedFunctionConstants);
}

test "Test Functions Calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, instructions, constants
    const test_cases = [_]struct { []const u8, []const []const u8, []const ExpectedFunctionConstants }{
        .{
            "fn(): 10; end();",
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpCall, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedFunctionConstants{
                ExpectedFunctionConstants{ .int = 10 },
                ExpectedFunctionConstants{
                    .instructions = &[_][]const u8{
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpReturnValue, &[_]usize{}),
                    },
                },
            },
        },
        .{
            \\var func = fn(): 10; end;
            \\func();
            ,
            &[_][]const u8{
                try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{1}),
                try bytecode_.make(&alloc, Opcode.OpSetGlobal, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpGetGlobal, &[_]usize{0}),
                try bytecode_.make(&alloc, Opcode.OpCall, &[_]usize{}),
                try bytecode_.make(&alloc, Opcode.OpPop, &[_]usize{}),
            },
            &[_]ExpectedFunctionConstants{
                ExpectedFunctionConstants{ .int = 10 },
                ExpectedFunctionConstants{
                    .instructions = &[_][]const u8{
                        try bytecode_.make(&alloc, Opcode.OpConstant, &[_]usize{0}),
                        try bytecode_.make(&alloc, Opcode.OpReturnValue, &[_]usize{}),
                    },
                },
            },
        },
    };

    try run_test(&alloc, test_cases, ExpectedFunctionConstants);
}

test "Test Compiler Scopes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var compiler = try Compiler.init(&alloc);
    const global_symbol_table = compiler.symbol_table;

    try std.testing.expectEqual(compiler.scope_index, 0);
    _ = try compiler.emit(Opcode.OpMul, &[_]usize{});

    try compiler.enter_scope();
    try std.testing.expectEqual(compiler.scope_index, 1);
    _ = try compiler.emit(Opcode.OpSub, &[_]usize{});
    try std.testing.expectEqual(compiler.scopes.items[compiler.scope_index].instructions.items.len, 1);
    try std.testing.expectEqual(compiler.scopes.items[compiler.scope_index].last_instruction.?.opcode, Opcode.OpSub);

    // Check enclose symbol table
    try std.testing.expectEqual(compiler.symbol_table.outer, global_symbol_table);

    _ = try compiler.leave_scope();
    // Check restore symbol table
    try std.testing.expectEqual(compiler.symbol_table, global_symbol_table);
    try std.testing.expectEqual(compiler.symbol_table.outer, null);

    try std.testing.expectEqual(compiler.scope_index, 0);

    _ = try compiler.emit(Opcode.OpAdd, &[_]usize{});
    try std.testing.expectEqual(compiler.scopes.items[compiler.scope_index].instructions.items.len, 2);
    try std.testing.expectEqual(compiler.scopes.items[compiler.scope_index].last_instruction.?.opcode, Opcode.OpAdd);
    try std.testing.expectEqual(compiler.scopes.items[compiler.scope_index].previous_instruction.?.opcode, Opcode.OpMul);
}

fn run_test(alloc: *const std.mem.Allocator, test_cases: anytype, comptime type_: ?type) !void {
    for (test_cases) |exp| {
        const root_node = try parse(exp[0], alloc);
        var compiler = try Compiler.init(alloc);
        try compiler.compile(root_node);

        const bytecode = compiler.get_bytecode();

        try test_instructions(alloc, exp[1], bytecode.instructions);
        // for (bytecode.instructions.items) |i| {
        //     std.debug.print("\t> {any}\n", .{i});
        // }
        if (type_ == i64) {
            try test_integer_constants(exp[2], bytecode.constants);
        } else if (type_ == []const u8) {
            try test_string_constants(exp[2], bytecode.constants);
        } else if (type_ == ExpectedHashConstant) {
            try test_hash_constants(exp[2], bytecode.constants);
        } else if (type_ == ExpectedFunctionConstants) {
            // try print_instruction(bytecode.instructions);
            try test_function_constants(exp[2], bytecode.constants);
        }
    }
}

fn parse(input: []const u8, alloc: *const std.mem.Allocator) !ast.Node {
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, alloc);

    const root_node = try parser.parse();
    return root_node;
}

fn test_instructions(
    alloc: *const std.mem.Allocator,
    expected: anytype,
    actual: std.ArrayList(u8),
) !void {
    var flattened_ = std.ArrayList(u8).init(alloc.*);
    for (expected) |exp| {
        for (exp) |b| {
            try flattened_.append(b);
        }
    }

    const flattened = try flattened_.toOwnedSlice();

    try std.testing.expectEqual(flattened.len, actual.items.len);

    for (flattened, actual.items) |exp, act| {
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

fn test_hash_constants(expected: []const ExpectedHashConstant, actual: std.ArrayList(*const Object)) !void {
    try std.testing.expectEqual(expected.len, actual.items.len);

    for (expected, actual.items) |exp, obj| {
        switch (obj.*) {
            .string => |string| {
                try std.testing.expectEqualStrings(exp.string, string.value);
            },
            .integer => |int| {
                try std.testing.expectEqual(exp.integer, int.value);
            },
            else => |other| {
                std.debug.print("Object is not a Hash, got: {any}\n", .{other});
            },
        }
    }
}

fn test_function_constants(expected: []const ExpectedFunctionConstants, actual: std.ArrayList(*const Object)) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    try std.testing.expectEqual(expected.len, actual.items.len);

    for (expected, actual.items) |exp, obj| {
        switch (obj.*) {
            .integer => |int| {
                try std.testing.expectEqual(exp.int, int.value);
            },
            .compiled_func => |func| {
                for (expected) |case| {
                    switch (case) {
                        .instructions => |ei| {
                            var flat = std.ArrayList(u8).init(alloc);

                            for (ei) |i| {
                                for (i) |b| {
                                    try flat.append(b);
                                }
                            }
                            const flattened = try flat.toOwnedSlice();

                            var func_i = func.instructions;
                            const func_slice = try func_i.toOwnedSlice();
                            try std.testing.expectEqualSlices(u8, flattened, func_slice);
                        },
                        .int => |int| {
                            _ = int;
                        },
                    }
                }
            },
            else => |other| {
                std.debug.print("Object is not a Function, got: {any}\n", .{other});
            },
        }
    }
}

fn print_instruction(i: std.ArrayList(u8)) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var v = std.ArrayList(u8).init(alloc);
    for (i.items) |b| {
        try v.append(b);
    }

    const def = try compiler_.opcode.Definitions.init(&alloc);
    const str = try bytecode_.to_string(&v, &alloc, &def);
    std.debug.print("{s}", .{str});
}
