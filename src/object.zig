const std = @import("std");

pub const ObjectType = union(enum) { Integer, Boolean, Null, Return };

pub const Object = union(enum) {
    integer: Integer,
    boolean: Boolean,
    null: Null,
    ret: Return,

    pub fn inspect(self: Object) void {
        switch (self) {
            .integer => |integer| integer.inspect(),
            .boolean => |boolean| boolean.inspect(),
            .null => |n| n.inspect(),
            .ret => |ret| ret.inspect(),
        }
    }
};

pub const Integer = struct {
    type: ObjectType,
    value: i64,

    pub fn inspect(self: Integer) void {
        std.debug.print("{d}\n", .{self.value});
    }
};

pub const Boolean = struct {
    type: ObjectType,
    value: bool,

    pub fn inspect(self: Boolean) void {
        std.debug.print("{?}\n", .{self.value});
    }
};

pub const Null = struct {
    type: ObjectType,

    pub fn inspect(_: Null) void {
        std.debug.print("null\n", .{});
    }
};

pub const Return = struct {
    type: ObjectType,
    value: *const Object,

    pub fn inspect(self: Return) void {
        self.value.inspect();
    }
};