const std = @import("std");

const Object = @import("object.zig").Object;

const EnvError = error{ MemAlloc, Undeclared, SetError };

pub const Environment = struct {
    string_map: std.hash_map.StringHashMap(*const Object),

    pub fn init(allocator: *const std.mem.Allocator) EnvError!Environment {
        return Environment{
            .string_map = std.hash_map.StringHashMap(*const Object).init(allocator.*),
        };
    }

    pub fn get(self: *Environment, name: []const u8) EnvError!?*const Object {
        const value = self.string_map.get(name) orelse return EnvError.Undeclared;
        return value;
    }

    pub fn set(self: *Environment, name: []const u8, value: *const Object) EnvError!?*const Object {
        self.string_map.put(name, value) catch return EnvError.SetError;
        return self.string_map.get(name);
    }
};
