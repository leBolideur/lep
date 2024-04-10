const std = @import("std");

pub const ObjectType = union(enum) { Integer, Boolean, Null };

pub const Object = union(enum) {
    integer: Integer,
    boolean: Boolean,
    null: Null,

    pub fn inspect(self: Object) void {
        switch (self) {
            .integer => |obj| obj.integer.inspect(),
            .boolean => |obj| obj.integer.inspect(),
            .null => |obj| obj.integer.inspect(),
        }
    }
};

pub const Integer = struct {
    type: ObjectType,
    value: u64,

    pub fn inspect(self: Integer) void {
        std.debug.print("{}", self.value);
    }
};

pub const Boolean = struct {
    type: ObjectType,
    value: bool,

    pub fn inspect(self: Boolean) void {
        std.debug.print("{}", self.value);
    }
};

pub const Null = struct {
    type: ObjectType,

    pub fn inspect(_: Null) void {
        std.debug.print("null");
    }
};
