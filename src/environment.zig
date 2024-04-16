const std = @import("std");

const Object = @import("object.zig").Object;

const ast = @import("ast.zig");

const EnvError = error{ MemAlloc, Undeclared, SetError };

pub const Environment = struct {
    var_table: std.hash_map.StringHashMap(*const Object),
    fn_table: std.hash_map.StringHashMap(*const Object),
    outer: ?*Environment,
    allocator: *const std.mem.Allocator,

    pub fn init(allocator: *const std.mem.Allocator) EnvError!Environment {
        return Environment{
            .var_table = std.hash_map.StringHashMap(*const Object).init(allocator.*),
            .fn_table = std.hash_map.StringHashMap(*const Object).init(allocator.*),
            .outer = null,
            .allocator = allocator,
        };
    }

    pub fn extend_env(
        self: *Environment,
        args: std.ArrayList(*const Object),
        params: std.ArrayList(ast.Identifier),
    ) EnvError!*Environment {
        var ptr = self.allocator.create(Environment) catch return EnvError.MemAlloc;
        ptr.* = Environment{
            .var_table = std.hash_map.StringHashMap(*const Object).init(self.allocator.*),
            .fn_table = std.hash_map.StringHashMap(*const Object).init(self.allocator.*),
            .outer = self,
            .allocator = self.allocator,
        };

        for (args.items, params.items) |arg, param| {
            // std.debug.print("arg >> {s}\tparam >> {s}\n", .{ arg.typename(), param.value });
            _ = ptr.add_var(param.value, arg) catch return EnvError.SetError;
        }

        return ptr;
    }

    pub fn get_var(self: *Environment, name: []const u8) EnvError!?*const Object {
        const ret = self.var_table.get(name);

        if (ret == null and self.outer != null) {
            return self.outer.?.var_table.get(name);
        }
        return ret;
    }

    pub fn add_var(self: *Environment, name: []const u8, value: *const Object) EnvError!*const Object {
        // TO FIX: investigate, not normal
        const dupe = self.allocator.dupe(u8, name) catch return EnvError.MemAlloc;
        self.var_table.put(dupe, value) catch return EnvError.SetError;

        return value;
    }

    // pub fn get_fn(self: *Environment, name: []const u8) EnvError!?*const Object {
    //     const ret = self.fn_table.get(name);

    //     if (ret == null and self.outer != null) {
    //         return self.outer.?.fn_table.get(name);
    //     }
    //     return ret;
    // }

    // pub fn add_fn(self: *Environment, value: *const Object) EnvError!*const Object {
    //     switch (value.*) {
    //         .func => |func| {
    //             // TO FIX: investigate, not normal
    //             // const dupe = self.allocator.dupe(u8, name) catch return EnvError.MemAlloc;
    //             self.fn_table.put(func.name, value) catch return EnvError.SetError;
    //         },
    //         else => {
    //             const stderr = std.io.getStdErr().writer();
    //             stderr.print("add_fn - object is not a function\n", .{}) catch {};
    //         },
    //     }

    //     return value;
    // }
};

test "test add and get" {
    const Integer = @import("object.zig").Integer;
    const ObjectType = @import("object.zig").ObjectType;

    const expected = [_]struct { []const u8, i64 }{
        .{ "a", 6 },
        .{ "foo", 4 },
        .{ "b", 16 },
        .{ "c", 66 },
        .{ "bar", 6 },
    };
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();
    var env = try Environment.init(&alloc);
    var expected_size: u32 = 0;

    for (expected) |exp| {
        var ptr = try alloc.create(Object);

        const result = Integer{ .type = ObjectType.Integer, .value = exp[1] };
        ptr.* = Object{ .integer = result };
        const added = try env.add_var(exp[0], ptr);

        const size = env.var_table.count();
        expected_size += 1;
        try std.testing.expectEqual(size, expected_size);
        try std.testing.expectEqual(added, ptr);

        const get = try env.get_var(exp[0]);
        try std.testing.expectEqual(get, ptr);

        // std.debug.print("{?} = {d}\n", .{ get, get.?.integer.value });
    }
}
