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

    var global = SymbolTable.new(&alloc);

    const a = try global.define("a");
    try std.testing.expectEqual(a, expected.get("a").?);

    const b = try global.define("b");
    try std.testing.expectEqual(b, expected.get("b").?);
}

test "Test SymbolTable Resolve Global" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const expected = [_]struct { Symbol }{
        .{Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0 }},
        .{Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1 }},
    };

    var global = SymbolTable.new(&alloc);
    _ = try global.define("a");
    _ = try global.define("b");

    for (expected) |exp| {
        const resolved = global.resolve(exp[0].name);
        try std.testing.expect(resolved != null);
        try std.testing.expectEqual(exp[0], resolved);
    }
}
