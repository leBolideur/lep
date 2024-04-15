const std = @import("std");

const Object = @import("object.zig").Object;

const EnvError = error{ MemAlloc, Undeclared, SetError };

pub const Environment = struct {
    table: std.hash_map.StringHashMap(*const Object),
    outer: ?*Environment,
    allocator: *const std.mem.Allocator,

    pub fn init(allocator: *const std.mem.Allocator) EnvError!Environment {
        return Environment{
            .table = std.hash_map.StringHashMap(*const Object).init(allocator.*),
            .outer = null,
            .allocator = allocator,
        };
    }

    pub fn extend_env(self: *Environment) EnvError!*Environment {
        var ptr = self.allocator.create(Environment) catch return EnvError.MemAlloc;
        ptr.* = Environment{
            .table = std.hash_map.StringHashMap(*const Object).init(self.allocator.*),
            .outer = self,
            .allocator = self.allocator,
        };

        return ptr;
    }

    pub fn get(self: *Environment, name: []const u8) EnvError!?*const Object {
        const ret = self.table.get(name);

        if (ret == null and self.outer != null) {
            return self.outer.?.table.get(name);
        }
        return ret;
    }

    pub fn add(self: *Environment, name: []const u8, value: *const Object) EnvError!*const Object {
        // TO FIX: investigate, not normal
        const dupe = self.allocator.dupe(u8, name) catch return EnvError.MemAlloc;
        self.table.put(dupe, value) catch return EnvError.SetError;

        return value;
    }
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
        const added = try env.add(exp[0], ptr);

        const size = env.table.count();
        expected_size += 1;
        try std.testing.expectEqual(size, expected_size);
        try std.testing.expectEqual(added, ptr);

        const get = try env.get(exp[0]);
        try std.testing.expectEqual(get, ptr);

        // std.debug.print("{?} = {d}\n", .{ get, get.?.integer.value });
    }
}
