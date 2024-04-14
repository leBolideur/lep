const std = @import("std");

pub const ObjectType = union(enum) { Integer, Boolean, Null, Return, Error, Ident };

pub const Object = union(enum) {
    integer: Integer,
    boolean: Boolean,
    null: Null,
    ret: Return,
    err: Error,
    ident: Ident,

    pub fn inspect(self: Object) void {
        switch (self) {
            .integer => |integer| integer.inspect(),
            .boolean => |boolean| boolean.inspect(),
            .null => |n| n.inspect(),
            .ret => |ret| ret.inspect(),
            .err => |err| err.inspect(),
            .ident => |ident| ident.inspect(),
        }
    }

    pub fn typename(self: Object) []const u8 {
        return switch (self) {
            .integer => "Integer",
            .boolean => "Boolean",
            .null => "Null",
            .ret => "Ret",
            .err => "Error",
            .ident => |ident| ident.name,
        };
    }
};

pub const Ident = struct {
    type: ObjectType,
    name: []const u8,
    value: *const Object,

    pub fn inspect(self: Ident) void {
        std.debug.print("{s} = ", .{self.name});
        self.value.*.inspect();
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

pub const Error = struct {
    type: ObjectType,
    msg: []const u8,

    pub fn inspect(self: Error) void {
        const stderr = std.io.getStdErr().writer();
        stderr.print("\nError: {s}\n", .{self.msg}) catch {};
    }
};
