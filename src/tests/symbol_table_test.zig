const std = @import("std");

const compiler_ = @import("compiler");
const SymbolScope = compiler_.symbol_table.SymbolScope;
const Symbol = compiler_.symbol_table.Symbol;
const SymbolTable = compiler_.symbol_table.SymbolTable;

test "Test SymbolTable Define Global" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var expected = std.StringHashMap(Symbol).init(alloc);
    try expected.put("a", Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0 });
    try expected.put("b", Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1 });
    try expected.put("c", Symbol{ .name = "c", .scope = SymbolScope.LOCAL, .index = 0 });
    try expected.put("d", Symbol{ .name = "d", .scope = SymbolScope.LOCAL, .index = 1 });
    try expected.put("e", Symbol{ .name = "e", .scope = SymbolScope.LOCAL, .index = 0 });
    try expected.put("f", Symbol{ .name = "f", .scope = SymbolScope.LOCAL, .index = 1 });

    var global = try SymbolTable.new(&alloc);

    const a = try global.define("a");
    try std.testing.expectEqual(a, expected.get("a").?);

    const b = try global.define("b");
    try std.testing.expectEqual(b, expected.get("b").?);

    var local = try SymbolTable.new_enclosed(&alloc, global);

    const c = try local.define("c");
    try std.testing.expectEqual(c, expected.get("c").?);

    const d = try local.define("d");
    try std.testing.expectEqual(d, expected.get("d").?);

    var nested = try SymbolTable.new_enclosed(&alloc, local);

    const e = try nested.define("e");
    try std.testing.expectEqual(e, expected.get("e").?);

    const f = try nested.define("f");
    try std.testing.expectEqual(f, expected.get("f").?);
}

test "Test SymbolTable Resolve Global" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const expected = [_]struct { Symbol }{
        .{Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0 }},
        .{Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1 }},
    };

    var global = try SymbolTable.new(&alloc);
    _ = try global.define("a");
    _ = try global.define("b");

    for (expected) |exp| {
        const resolved = global.resolve(exp[0].name);
        try std.testing.expect(resolved != null);
        try std.testing.expectEqual(exp[0], resolved);
    }
}

test "Test SymbolTable Resolve Local" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const expected = [_]struct { Symbol }{
        .{Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0 }},
        .{Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1 }},
        .{Symbol{ .name = "c", .scope = SymbolScope.LOCAL, .index = 0 }},
        .{Symbol{ .name = "d", .scope = SymbolScope.LOCAL, .index = 1 }},
    };

    var global = try SymbolTable.new(&alloc);
    _ = try global.define("a");
    _ = try global.define("b");

    var local = try SymbolTable.new_enclosed(&alloc, global);
    _ = try local.define("c");
    _ = try local.define("d");

    for (expected) |exp| {
        const resolved = local.resolve(exp[0].name);

        try std.testing.expect(resolved != null);
        try std.testing.expectEqual(exp[0], resolved);
    }
}

test "Test Nested SymbolTable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var global = try SymbolTable.new(&alloc);
    _ = try global.define("a");
    _ = try global.define("b");

    var local = try SymbolTable.new_enclosed(&alloc, global);
    _ = try local.define("c");
    _ = try local.define("d");

    var nested = try SymbolTable.new_enclosed(&alloc, local);
    _ = try nested.define("e");
    _ = try nested.define("f");

    const expected = [_]struct { *SymbolTable, []const Symbol }{
        .{
            local,
            &[_]Symbol{
                Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0 },
                Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1 },
                Symbol{ .name = "c", .scope = SymbolScope.LOCAL, .index = 0 },
                Symbol{ .name = "d", .scope = SymbolScope.LOCAL, .index = 1 },
            },
        },
        .{
            nested,
            &[_]Symbol{
                Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0 },
                Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1 },
                Symbol{ .name = "e", .scope = SymbolScope.LOCAL, .index = 0 },
                Symbol{ .name = "f", .scope = SymbolScope.LOCAL, .index = 1 },
            },
        },
    };

    for (expected) |tt| {
        for (tt[1]) |exp| {
            const resolved = tt[0].resolve(exp.name);

            try std.testing.expect(resolved != null);
            try std.testing.expectEqual(exp, resolved);
        }
    }
}

test "Test Define/Resolve Builtins" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var global = try SymbolTable.new(&alloc);
    const local = try SymbolTable.new_enclosed(&alloc, global);
    const nested = try SymbolTable.new_enclosed(&alloc, local);

    const expected = [4]Symbol{
        Symbol{ .name = "a", .scope = SymbolScope.BUILTIN, .index = 0 },
        Symbol{ .name = "b", .scope = SymbolScope.BUILTIN, .index = 1 },
        Symbol{ .name = "c", .scope = SymbolScope.BUILTIN, .index = 2 },
        Symbol{ .name = "d", .scope = SymbolScope.BUILTIN, .index = 3 },
    };

    for (expected, 0..) |sym, index| {
        _ = try global.define_builtin(index, sym.name);
    }

    const tables = [3]*SymbolTable{ global, local, nested };
    for (tables) |table| {
        for (expected) |symbol| {
            const resolved = table.*.resolve(symbol.name);

            try std.testing.expect(resolved != null);
            try std.testing.expectEqual(symbol, resolved);
        }
    }
}
