const std = @import("std");

const common = @import("common");

const Object = common.object.Object;

const ast = common.ast;

const EnvError = error{ MemAlloc, Undeclared, SetError };

pub const Environment = struct {
    var_table: std.hash_map.StringHashMap(*const Object),
    outer: ?*const Environment,
    allocator: *const std.mem.Allocator,

    pub fn init(allocator: *const std.mem.Allocator) EnvError!Environment {
        return Environment{
            .var_table = std.hash_map.StringHashMap(*const Object).init(allocator.*),
            .outer = null,
            .allocator = allocator,
        };
    }

    pub fn extend_env(
        self: *const Environment,
        args: std.ArrayList(*const Object),
        params: std.ArrayList(ast.Identifier),
    ) EnvError!*Environment {
        var ptr = self.allocator.create(Environment) catch return EnvError.MemAlloc;
        ptr.* = Environment{
            .var_table = std.hash_map.StringHashMap(*const Object).init(self.allocator.*),
            .outer = self,
            .allocator = self.allocator,
        };

        for (args.items, params.items) |arg, param| {
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
        self.var_table.put(name, value) catch return EnvError.SetError;

        // std.debug.print("\nTable content :\n", .{});
        // var iter = self.var_table.iterator();
        // while (iter.next()) |item| {
        //     var buf = std.ArrayList(u8).init(self.allocator.*);
        //     item.value_ptr.*.inspect(&buf) catch {};
        //     const str = buf.toOwnedSlice() catch "";
        //     std.debug.print("\t>{s} = {s}\n", .{ item.key_ptr.*, str });
        // }

        return value;
    }
};

test "test add and get" {
    const Integer = @import("object").Integer;
    const ObjectType = @import("object").ObjectType;

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
        const ptr = try alloc.create(Object);

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
