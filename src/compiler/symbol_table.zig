const std = @import("std");

const Token = @import("common").token.Token;

pub const SymbolTableError = error{ AddSymbol, AlreadyDeclared };

pub const SymbolScope = enum(u8) {
    GLOBAL = 0,
    LOCAL,
    BUILTIN,
};

pub const SymbolType = enum(u8) { VAR = 0, CONST, FUNC };

pub const Symbol = struct {
    name: []const u8,
    scope: SymbolScope,
    index: usize,

    used: bool = false,
    token: Token = undefined,
    sym_type: SymbolType = undefined,
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

    pub fn define(self: *SymbolTable, identifier: []const u8, token: Token, sym_type: SymbolType) SymbolTableError!Symbol {
        const exist = self.store.get(identifier);
        if (exist != null) return SymbolTableError.AlreadyDeclared;

        const scope = if (self.outer == null) SymbolScope.GLOBAL else SymbolScope.LOCAL;
        const sym = Symbol{
            .name = identifier,
            .scope = scope,
            .index = self.definitions_count,

            .used = false,
            .token = token,
            .sym_type = sym_type,
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

            .used = undefined,
            .token = undefined,
            .sym_type = SymbolType.FUNC,
        };

        self.store.putNoClobber(name, sym) catch return SymbolTableError.AlreadyDeclared;
        return sym;
    }

    pub fn resolve(self: *SymbolTable, identifier: []const u8) ?*Symbol {
        var obj = self.store.getPtr(identifier);
        if (obj == null and self.outer != null) {
            obj = self.outer.?.resolve(identifier);
        }

        if (obj != null)
            obj.?.*.used = true;

        return obj;
    }
};
