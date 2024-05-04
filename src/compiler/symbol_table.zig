const std = @import("std");

const SymbolTableError = error{AddSymbol};

pub const SymbolScope = enum(u8) {
    GLOBAL = 0,
    LOCAL,
    BUILTIN,
};

pub const Symbol = struct {
    name: []const u8,
    scope: SymbolScope,
    index: usize,
};

pub const SymbolTable = struct {
    outer: ?*SymbolTable,
    store: std.StringHashMap(Symbol),
    definitions_count: usize,

    pub fn new(alloc: *const std.mem.Allocator) !*SymbolTable {
        const ptr = try alloc.create(SymbolTable);

        ptr.* = SymbolTable{
            .outer = null,
            .store = std.StringHashMap(Symbol).init(alloc.*),
            .definitions_count = 0,
        };

        return ptr;
    }

    pub fn new_enclosed(alloc: *const std.mem.Allocator, outer: *SymbolTable) !*SymbolTable {
        var new_st = try SymbolTable.new(alloc);
        new_st.outer = outer;
        return new_st;
    }

    pub fn define(self: *SymbolTable, identifier: []const u8) SymbolTableError!Symbol {
        const scope = if (self.outer == null) SymbolScope.GLOBAL else SymbolScope.LOCAL;
        const sym = Symbol{
            .name = identifier,
            .scope = scope,
            .index = self.definitions_count,
        };

        self.store.put(identifier, sym) catch return SymbolTableError.AddSymbol;
        self.definitions_count += 1;

        return sym;
    }

    pub fn define_builtin(self: *SymbolTable, index: usize, name: []const u8) SymbolTableError!Symbol {
        const sym = Symbol{
            .name = name,
            .scope = SymbolScope.BUILTIN,
            .index = index,
        };

        self.store.put(name, sym) catch return SymbolTableError.AddSymbol;
        return sym;
    }

    pub fn resolve(self: SymbolTable, identifier: []const u8) ?Symbol {
        var obj = self.store.get(identifier);
        if (obj == null and self.outer != null) {
            obj = self.outer.?.resolve(identifier);
        }

        return obj;
    }
};

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

    const expected = [_]struct { *const SymbolTable, []const Symbol }{
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
