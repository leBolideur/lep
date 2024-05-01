const std = @import("std");

const SymbolTableError = error{AddSymbol};

pub const SymbolScope = enum(u8) {
    GLOBAL = 0,
    LOCAL,
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

    pub fn resolve(self: SymbolTable, identifier: []const u8) ?Symbol {
        var obj = self.store.get(identifier);
        if (obj == null and self.outer != null) {
            obj = self.outer.?.resolve(identifier);
        }
        return obj;
    }
};
