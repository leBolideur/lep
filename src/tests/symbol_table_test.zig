const std = @import("std");

const compiler_ = @import("compiler");
const SymbolScope = compiler_.symbol_table.SymbolScope;
const Symbol = compiler_.symbol_table.Symbol;
const SymbolTable = compiler_.symbol_table.SymbolTable;
const SymbolType = compiler_.symbol_table.SymbolType;

const interpreter = @import("interpreter");
const TokenType = interpreter.token.TokenType;
const Token = interpreter.token.Token;

// For testing purpose only
fn test_token(name: []const u8) Token {
    return Token{
        .type = TokenType.ILLEGAL,
        .literal = name,
        .line = 1,
        .col = 2,
    };
}

test "Test SymbolTable Define Global" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var expected = std.StringHashMap(Symbol).init(alloc);
    try expected.put("a", Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0, .used = false, .sym_type = SymbolType.VAR, .token = undefined });
    try expected.put("b", Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1, .used = false, .sym_type = SymbolType.VAR, .token = undefined });
    try expected.put("c", Symbol{ .name = "c", .scope = SymbolScope.LOCAL, .index = 0, .used = false, .sym_type = SymbolType.VAR, .token = undefined });
    try expected.put("d", Symbol{ .name = "d", .scope = SymbolScope.LOCAL, .index = 1, .used = false, .sym_type = SymbolType.VAR, .token = undefined });
    try expected.put("e", Symbol{ .name = "e", .scope = SymbolScope.LOCAL, .index = 0, .used = false, .sym_type = SymbolType.VAR, .token = undefined });
    try expected.put("f", Symbol{ .name = "f", .scope = SymbolScope.LOCAL, .index = 1, .used = false, .sym_type = SymbolType.VAR, .token = undefined });

    var global = try SymbolTable.new(&alloc);

    const a = try global.define("a", test_token("a"), SymbolType.VAR);
    std.debug.print("a >> {any}\n", .{a});
    try std.testing.expectEqual(a, expected.get("a").?);

    const b = try global.define("b", test_token("b"), SymbolType.VAR);
    try std.testing.expectEqual(b, expected.get("b").?);

    var local = try SymbolTable.new_enclosed(&alloc, global);

    const c = try local.define("c", test_token("c"), SymbolType.VAR);
    try std.testing.expectEqual(c, expected.get("c").?);

    const d = try local.define("d", test_token("d"), SymbolType.VAR);
    try std.testing.expectEqual(d, expected.get("d").?);

    var nested = try SymbolTable.new_enclosed(&alloc, local);

    const e = try nested.define("e", test_token("e"), SymbolType.VAR);
    try std.testing.expectEqual(e, expected.get("e").?);

    const f = try nested.define("f", test_token("f"), SymbolType.VAR);
    try std.testing.expectEqual(f, expected.get("f").?);
}

test "Test SymbolTable Resolve Global" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const expected = [_]struct { Symbol }{
        .{Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0, .used = true }},
        .{Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1, .used = true }},
    };

    var global = try SymbolTable.new(&alloc);
    _ = try global.define("a", test_token("a"), SymbolType.VAR);
    _ = try global.define("b", test_token("b"), SymbolType.VAR);

    for (expected) |exp| {
        const resolved = global.resolve(exp[0].name);
        try std.testing.expect(resolved != null);
        try std.testing.expectEqual(exp[0], resolved.?.*);
    }
}

test "Test SymbolTable Resolve Local" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const expected = [_]struct { Symbol }{
        .{Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0, .used = true }},
        .{Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1, .used = true }},
        .{Symbol{ .name = "c", .scope = SymbolScope.LOCAL, .index = 0, .used = true }},
        .{Symbol{ .name = "d", .scope = SymbolScope.LOCAL, .index = 1, .used = true }},
    };

    var global = try SymbolTable.new(&alloc);
    _ = try global.define("a", test_token("a"), SymbolType.VAR);
    _ = try global.define("b", test_token("b"), SymbolType.VAR);

    var local = try SymbolTable.new_enclosed(&alloc, global);
    _ = try local.define("c", test_token("c"), SymbolType.VAR);
    _ = try local.define("d", test_token("d"), SymbolType.VAR);

    for (expected) |exp| {
        const resolved = local.resolve(exp[0].name);

        try std.testing.expect(resolved != null);
        try std.testing.expectEqual(exp[0], resolved.?.*);
    }
}

test "Test Nested SymbolTable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    var global = try SymbolTable.new(&alloc);
    _ = try global.define("a", test_token("a"), SymbolType.VAR);
    _ = try global.define("b", test_token("b"), SymbolType.VAR);

    var local = try SymbolTable.new_enclosed(&alloc, global);
    _ = try local.define("c", test_token("c"), SymbolType.VAR);
    _ = try local.define("d", test_token("d"), SymbolType.VAR);

    var nested = try SymbolTable.new_enclosed(&alloc, local);
    _ = try nested.define("e", test_token("e"), SymbolType.VAR);
    _ = try nested.define("f", test_token("f"), SymbolType.VAR);

    const expected = [_]struct { *SymbolTable, []const Symbol }{
        .{
            local,
            &[_]Symbol{
                Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0, .used = true },
                Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1, .used = true },
                Symbol{ .name = "c", .scope = SymbolScope.LOCAL, .index = 0, .used = true },
                Symbol{ .name = "d", .scope = SymbolScope.LOCAL, .index = 1, .used = true },
            },
        },
        .{
            nested,
            &[_]Symbol{
                Symbol{ .name = "a", .scope = SymbolScope.GLOBAL, .index = 0, .used = true },
                Symbol{ .name = "b", .scope = SymbolScope.GLOBAL, .index = 1, .used = true },
                Symbol{ .name = "e", .scope = SymbolScope.LOCAL, .index = 0, .used = true },
                Symbol{ .name = "f", .scope = SymbolScope.LOCAL, .index = 1, .used = true },
            },
        },
    };

    for (expected) |tt| {
        for (tt[1]) |exp| {
            const resolved = tt[0].resolve(exp.name);

            try std.testing.expect(resolved != null);
            try std.testing.expectEqual(exp, resolved.?.*);
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
        Symbol{ .name = "a", .scope = SymbolScope.BUILTIN, .index = 0, .used = true, .sym_type = SymbolType.FUNC },
        Symbol{ .name = "b", .scope = SymbolScope.BUILTIN, .index = 1, .used = true, .sym_type = SymbolType.FUNC },
        Symbol{ .name = "c", .scope = SymbolScope.BUILTIN, .index = 2, .used = true, .sym_type = SymbolType.FUNC },
        Symbol{ .name = "d", .scope = SymbolScope.BUILTIN, .index = 3, .used = true, .sym_type = SymbolType.FUNC },
    };

    for (expected, 0..) |sym, index| {
        _ = try global.define_builtin(index, sym.name);
    }

    const tables = [3]*SymbolTable{ global, local, nested };
    for (tables) |table| {
        for (expected) |symbol| {
            const resolved = table.*.resolve(symbol.name);

            try std.testing.expect(resolved != null);
            try std.testing.expectEqual(symbol, resolved.?.*);
        }
    }
}
