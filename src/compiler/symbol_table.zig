const std = @import("std");

const SymbolTableError = error{AddSymbol};

pub const SymbolScope = enum(u8) {
    GLOBAL = 0,
};

pub const Symbol = struct {
    name: []const u8,
    scope: SymbolScope,
    index: usize,
};

pub const SymbolTable = struct {
    store: std.StringHashMap(Symbol),
    definitions_count: usize,

    pub fn new(alloc: *const std.mem.Allocator) SymbolTable {
        return SymbolTable{
            .store = std.StringHashMap(Symbol).init(alloc.*),
            .definitions_count = 0,
        };
    }

    pub fn define(self: *SymbolTable, identifier: []const u8) SymbolTableError!Symbol {
        const sym = Symbol{
            .name = identifier,
            .scope = SymbolScope.GLOBAL,
            .index = self.definitions_count,
        };

        self.store.put(identifier, sym) catch return SymbolTableError.AddSymbol;
        self.definitions_count += 1;

        return sym;
    }

    pub fn resolve(self: SymbolTable, identifier: []const u8) ?Symbol {
        return self.store.get(identifier);
    }
};
