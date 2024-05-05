const std = @import("std");

const interpreter = @import("interpreter");
const common = @import("common");
const compiler_ = @import("compiler");

const eval_utils = common.eval_utils;

const Lexer = common.lexer.Lexer;
const Parser = common.parser.Parser;
const Object = common.object.Object;
const ast = common.ast;

const opcode = compiler_.opcode;

const Compiler = compiler_.compiler.Compiler;

const VM = compiler_.vm.VM;
const VMError = compiler_.vm.VMError;

const null_object = compiler_.vm.null_object;

const ExpectedValue = union(enum) {
    integer: isize,
    boolean: bool,
    null_: *const Object,
    string: []const u8,
    int_array: []const i8,
    map: std.StringHashMap(*const Object),
};

test "Test the VM with Integers arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{ "1;", 1, 0 },
        .{ "2;", 2, 0 },
        .{ "-12;", -12, 0 },
        .{ "-50 + 100 + -50", 0, 0 },
        .{ "(5 + 10 * 2 + 15 / 3) * 2 + -10", 50, 0 },
        .{ "6 + 6;", 12, 0 },
        .{ "5 - 6;", -1, 0 },
        .{ "6 * 6;", 36, 0 },
        .{ "6 / 6;", 1, 0 },
        .{ "50 / 2 * 2 + 10 - 5", 55, 0 },
        .{ "5 * (2 + 10)", 60, 0 },
        .{ "5 + 5 + 5 + 5 - 10", 10, 0 },
        .{ "2 * 2 * 2 * 2 * 2", 32, 0 },
        .{ "5 * 2 + 10", 20, 0 },
        .{ "5 + 2 * 10", 25, 0 },
        .{ "5 * (2 + 10)", 60, 0 },
    };

    try run_test(&alloc, test_cases, isize);
}

test "Test the VM with Booleans expressions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, bool, usize }{
        .{ "true;", true, 0 },
        .{ "false;", false, 0 },
        .{ "1 < 2;", true, 0 },
        .{ "1 > 2", false, 0 },
        .{ "1 < 1", false, 0 },
        .{ "1 > 1", false, 0 },
        .{ "1 == 1", true, 0 },
        .{ "1 != 1", false, 0 },
        .{ "1 == 2", false, 0 },
        .{ "1 != 2", true, 0 },
        .{ "true == true", true, 0 },
        .{ "false == false", true, 0 },
        .{ "true == false", false, 0 },
        .{ "true != false", true, 0 },
        .{ "false != true", true, 0 },
        .{ "(1 < 2) == true", true, 0 },
        .{ "(1 < 2) == false", false, 0 },
        .{ "(1 > 2) == true", false, 0 },
        .{ "(1 > 2) == false", true, 0 },
        .{ "!true", false, 0 },
        .{ "!false", true, 0 },
        .{ "!!true", true, 0 },
        .{ "!!false", false, 0 },
    };

    try run_test(&alloc, test_cases, bool);
}

test "Test the VM with Conditionals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{ "if (true): 9; end", 9, 0 },
        .{ "if (true): 11; else: 21; end", 11, 0 },
        .{ "if (false): 13; else: 22; end", 22, 0 },
        .{ "if (1 < 2): 8; end", 8, 0 },
        .{ "if (1 < 2): 10; else: 23; end", 10, 0 },
        .{ "if (1 > 2): 10; else: 24; end", 24, 0 },
    };

    try run_test(&alloc, test_cases, isize);
}

test "Test the VM  Conditionals with Null object" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, *const Object, usize }{
        .{ "if (1 > 2): 10; end", null_object, 0 },
        .{ "if (false): 10; end", null_object, 0 },
    };

    try run_test(&alloc, test_cases, *const Object);
}

test "Test the VM Bindings" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{ "var one = 1; one", 1, 0 },
        .{ "var one = 2; var two = 2; one + two", 4, 0 },
        .{ "var one = 1; var two = one + one; one + two", 3, 0 },
    };

    try run_test(&alloc, test_cases, isize);
}

test "Test VM Strings expressions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, []const u8, usize }{
        .{
            \\"Hello";
            ,
            "Hello",
            0,
        },
        .{
            \\"Hello" + ", " + "World!";
            ,
            "Hello, World!",
            0,
        },
    };

    try run_test(&alloc, test_cases, []const u8);
}

test "Test VM Array with Integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, []const i8, usize }{
        .{
            "[]",
            &[_]i8{},
            0,
        },
        .{
            "[1, 3, 4];",
            &[_]i8{ 1, 3, 4 },
            0,
        },
        .{
            "[1 + 2, 6 * 7, 6 - 9];",
            &[_]i8{ 3, 42, -3 },
            0,
        },
    };

    try run_test(&alloc, test_cases, []const i8);
}

test "Test VM Hash with Integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const map = std.StringHashMap(*const Object).init(alloc);

    var map1 = std.StringHashMap(*const Object).init(alloc);
    const one = try eval_utils.new_integer(&alloc, 1);
    try map1.put("one", one);
    const two = try eval_utils.new_integer(&alloc, 2);
    try map1.put("two", two);

    var map2 = std.StringHashMap(*const Object).init(alloc);
    const t = try eval_utils.new_integer(&alloc, 10);
    try map2.put("foo", t);
    const tt = try eval_utils.new_integer(&alloc, 7);
    try map2.put("bar", tt);

    // expr, result, remaining element on stacks
    const test_cases = [_]struct {
        []const u8,
        std.StringHashMap(*const Object),
        usize,
    }{
        .{
            \\{};
            ,
            map,
            0,
        },
        .{
            \\{"one": 1, "two": 2};
            ,
            map1,
            0,
        },
        .{
            \\{"foo": 9 + 1, "bar": 3 * 2 + 1};
            ,
            map2,
            0,
        },
    };

    try run_test(&alloc, test_cases, std.StringHashMap(*const Object));
}

test "Test VM Index expressions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{ "[1, 2, 3][1];", 2, 0 },
        .{ "[1, 2, 3][0 + 2];", 3, 0 },
        .{
            \\{"one": 1, "two": 2}["one"];
            ,
            1,
            0,
        },
        .{
            \\{"one": 1, "two": 2}["two"];
            ,
            2,
            0,
        },
    };

    try run_test(&alloc, test_cases, isize);
}

test "Test VM Index expressions - null cases" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, *const Object, usize }{
        .{ "[][0]", null_object, 0 },
        .{ "[1, 2, 3][99]", null_object, 0 },
        .{ "[1][-1]", null_object, 0 },
        .{
            \\{"one": 1}["two"]
            ,
            null_object,
            0,
        },
        // FIXME: empty string index bug...
        // .{
        //     \\{}[""];
        //     ,
        //     null_object,
        //     0,
        // },
    };

    try run_test(&alloc, test_cases, *const Object);
}

test "Test VM Calling functions without arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{
            \\var test = fn(): ret 1 + 5; end;
            \\test();
            ,
            6,
            0,
        },
        // Implicit return
        .{
            \\var test = fn(): 3 + 5; end;
            \\test();
            ,
            8,
            0,
        },
        .{
            \\var test = fn(): ret 1 + 5; end;
            \\var same = fn(): test(); end;
            \\test() + same();
            ,
            12,
            0,
        },
        // First class function
        .{
            \\var test = fn(): ret 1 + 5; end;
            \\var same = fn(): ret test; end;
            \\same()();
            ,
            6,
            0,
        },
    };

    try run_test(&alloc, test_cases, isize);
}

test "Test VM Calling functions without body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, *const Object, usize }{
        .{
            \\var test = fn():  end;
            \\test();
            ,
            null_object,
            0,
        },
        .{
            \\var test = fn():  end;
            \\var same = fn(): test(); end;
            \\same();
            ,
            null_object,
            0,
        },
    };

    try run_test(&alloc, test_cases, *const Object);
}

test "Test VM Calling functions with bindings" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{
            \\var one = fn(): var one = 1; one; end;
            \\one();
            ,
            1,
            0,
        },
        .{
            \\var oneAndTwo = fn(): var one = 1; var two = 2; one + two; end;
            \\oneAndTwo();
            ,
            3,
            0,
        },
        .{
            \\var one = fn(): var one = 1; one; end;
            \\var one_bis = fn(): var one = 1; one; end;
            \\one() + one_bis();
            ,
            2,
            0,
        },
        .{
            \\var oneAndTwo = fn(): var one = 1; var two = 2; one + two; end;
            \\var threeAndFour = fn(): var three = 3; var four = 4; three + four; end;
            \\oneAndTwo() + threeAndFour();
            ,
            10,
            0,
        },
        .{
            \\var globalSeed = 50;
            \\var minusOne = fn(): var num = 1; globalSeed - num; end;
            \\var minusTwo = fn(): var num = 2; globalSeed - num; end;
            \\minusOne() + minusTwo();
            ,
            97,
            0,
        },
    };

    try run_test(&alloc, test_cases, isize);
}

test "Test VM Calling functions with arguments bindings" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, isize, usize }{
        .{
            \\var get = fn(a): ret a; end;
            \\get(5);
            ,
            5,
            0,
        },
        .{
            \\var sub = fn(a, b): ret a - b; end;
            \\sub(5, 6);
            ,
            -1,
            0,
        },
        .{
            \\var sub = fn(a, b):
            \\  var result = a - b;
            \\  ret result;
            \\end;
            \\sub(5, 6);
            ,
            -1,
            0,
        },
        .{
            \\var sub = fn(a, b):
            \\  var result = a - b;
            \\  ret result;
            \\end;
            \\sub(5, 6) + sub(11, 1);
            ,
            9,
            0,
        },
        .{
            \\var sub = fn(a, b):
            \\  var result = a - b;
            \\  ret result;
            \\end;
            \\var outer = fn(a, b): ret sub(a, b); end;
            \\outer(10, 10);
            ,
            0,
            0,
        },
        .{
            \\var globalNum = 10;
            \\var sum = fn(a, b):
            \\var c = a + b;
            \\c + globalNum;
            \\end;
            \\var outer = fn():
            \\sum(1, 2) + sum(3, 4) + globalNum;
            \\end;
            \\outer() + globalNum;
            ,
            50,
            0,
        },
    };

    try run_test(&alloc, test_cases, isize);
}

test "Test VM Calling functions with wrong number of arguments, expect errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, []const u8 }{
        .{
            \\var test = fn():  end;
            \\test(1);
            ,
            "Wrong number of arguments, want=0 got=1",
        },
        .{
            \\var test = fn(a): a;  end;
            \\test();
            ,
            "Wrong number of arguments, want=1 got=0",
        },
    };

    for (test_cases) |exp| {
        const root_node = try parse(exp[0], &alloc);
        var compiler = try Compiler.init(&alloc);
        try compiler.compile(root_node);

        const bytecode = compiler.get_bytecode();

        var vm = try VM.new(&alloc, bytecode);
        const ret = try vm.run();
        _ = vm.last_popped_element();

        switch (ret.?.*) {
            .err => |err| {
                try std.testing.expectEqualStrings(exp[1], err.msg);
            },
            else => unreachable,
        }
    }
}

test "Test VM Builtins functions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    // expr, result, remaining element on stacks
    const test_cases = [_]struct { []const u8, ExpectedValue }{
        .{
            \\len([]);
            ,
            ExpectedValue{ .integer = 0 },
        },
        .{
            \\len("hello");
            ,
            ExpectedValue{ .integer = 5 },
        },
        .{
            \\len(1);
            ,
            ExpectedValue{ .string = "argument to `len` not supported, got Integer" },
        },
        .{
            \\len("one", "two");
            ,
            ExpectedValue{ .string = "wrong number of arguments. want=1, got=2" },
        },
        .{
            \\len([1, 2, 3]);
            ,
            ExpectedValue{ .integer = 3 },
        },
        // .{
        //     \\print("hello");
        //     ,
        //     ExpectedValue{ .null_ = null_object },
        // },
        .{
            \\head([1, 2, 4]);
            ,
            ExpectedValue{ .integer = 1 },
        },
        .{
            \\head([]);
            ,
            ExpectedValue{ .string = "`head` is not applicable on empty array." },
        },
        .{
            \\last([1, 4, 9]);
            ,
            ExpectedValue{ .integer = 9 },
        },
        .{
            \\tail([1, 4, 8]);
            ,
            ExpectedValue{ .int_array = &[2]i8{ 4, 8 } },
        },
        .{
            \\push([], 1);
            ,
            ExpectedValue{ .int_array = &[1]i8{1} },
        },
        .{
            \\push([1, 3], 6);
            ,
            ExpectedValue{ .int_array = &[3]i8{ 1, 3, 6 } },
        },
    };

    for (test_cases) |exp| {
        const root_node = try parse(exp[0], &alloc);
        var compiler = try Compiler.init(&alloc);
        try compiler.compile(root_node);

        const bytecode = compiler.get_bytecode();

        var vm = try VM.new(&alloc, bytecode);
        const ret = try vm.run();
        const last = vm.last_popped_element();
        _ = ret;

        try test_expected_object(exp[1], last);
    }
}

fn expected_same_type(object: *const Object, value: ExpectedValue) bool {
    switch (object.*) {
        .integer => {
            switch (value) {
                .integer => return true,
                else => return false,
            }
        },
        .boolean => {
            switch (value) {
                .boolean => return true,
                else => return false,
            }
        },
        .null => {
            switch (value) {
                .null_ => return true,
                else => return false,
            }
        },
        .string => {
            switch (value) {
                .string => return true,
                else => return false,
            }
        },
        .array => {
            switch (value) {
                .int_array => return true,
                else => return false,
            }
        },
        .hash => {
            switch (value) {
                .map => return true,
                else => return false,
            }
        },
        else => |other| {
            std.debug.print("Unknown type, got: {any}\n", .{other});
            return false;
        },
    }
}

fn run_test(alloc: *const std.mem.Allocator, test_cases: anytype, comptime type_: type) !void {
    for (test_cases) |exp| {
        const root_node = try parse(exp[0], alloc);
        var compiler = try Compiler.init(alloc);
        try compiler.compile(root_node);

        const bytecode = compiler.get_bytecode();

        var vm = try VM.new(alloc, bytecode);
        _ = try vm.run();
        const last = vm.last_popped_element();

        // Remaining element on the stack
        try std.testing.expectEqual(exp[2], vm.sp);

        const expected = switch (type_) {
            isize => ExpectedValue{ .integer = exp[1] },
            bool => ExpectedValue{ .boolean = exp[1] },
            *const Object => ExpectedValue{ .null_ = exp[1] },
            []const u8 => ExpectedValue{ .string = exp[1] },
            []const i8 => ExpectedValue{ .int_array = exp[1] },
            std.StringHashMap(*const Object) => ExpectedValue{ .map = exp[1] },
            else => unreachable,
        };

        const is_same_type = expected_same_type(last.?, expected);
        try std.testing.expect(is_same_type);

        try test_expected_object(expected, last);
    }
}

fn parse(input: []const u8, alloc: *const std.mem.Allocator) !ast.Node {
    var lexer = Lexer.init(input);
    var parser = try Parser.init(&lexer, alloc);

    const root_node = try parser.parse();
    return root_node;
}

fn test_expected_object(expected: ExpectedValue, actual: ?*const Object) !void {
    try std.testing.expect(actual != null);

    switch (actual.?.*) {
        .integer => |int| {
            try std.testing.expectEqual(expected.integer, @as(isize, @intCast(int.value)));
        },
        .boolean => |boo| {
            try std.testing.expectEqual(expected.boolean, boo.value);
        },
        .null => {
            try std.testing.expectEqual(expected.null_, null_object);
        },
        .string => |string| {
            try std.testing.expectEqualStrings(expected.string, string.value);
        },
        .array => |array| {
            try std.testing.expectEqual(expected.int_array.len, array.elements.items.len);
            for (expected.int_array, array.elements.items) |exp, act| {
                switch (act.*) {
                    .integer => |int| {
                        try std.testing.expectEqual(exp, int.value);
                    },
                    else => unreachable,
                }
            }
        },
        .hash => |hash| {
            try std.testing.expectEqual(expected.map.count(), hash.pairs.count());
            var iterator = hash.pairs.iterator();
            var i: usize = 0;
            while (iterator.next()) |exp| : (i += 1) {
                const key = exp.key_ptr.*;
                const value = exp.value_ptr.*;

                const tt = expected.map.get(key).?;

                switch (value.*) {
                    .integer => |int| {
                        try std.testing.expectEqual(tt.integer.value, int.value);
                    },
                    else => unreachable,
                }
            }
        },
        else => |other| {
            std.debug.print("Object cannot be tested, got: {any}\n", .{other});
        },
    }
}
