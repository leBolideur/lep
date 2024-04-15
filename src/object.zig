const std = @import("std");

const ast = @import("ast.zig");
const Environment = @import("environment.zig").Environment;

pub const ObjectType = union(enum) { Integer, Boolean, Null, Return, Error, Func };

pub const ObjectError = error{InspectFormatError};

pub const Object = union(enum) {
    integer: Integer,
    boolean: Boolean,
    null: Null,
    ret: Return,
    err: Error,
    func: Func,

    pub fn inspect(self: Object, buf: *std.ArrayList(u8)) ObjectError!void {
        try switch (self) {
            .integer => |integer| integer.inspect(buf),
            .boolean => |boolean| boolean.inspect(buf),
            .null => |n| n.inspect(buf),
            .ret => |ret| ret.inspect(buf),
            .err => |err| err.inspect(buf),
            .func => |func| func.inspect(buf),
        };
    }

    pub fn typename(self: Object) []const u8 {
        return switch (self) {
            .integer => "Integer",
            .boolean => "Boolean",
            .null => "Null",
            .ret => "Ret",
            .err => "Error",
            .func => "Func",
        };
    }
};

pub const Func = struct {
    type: ObjectType,
    parameters: std.ArrayList(ast.Identifier),
    body: ast.BlockStatement,
    env: *const Environment,

    pub fn inspect(self: Func, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "fn(", .{}) catch return ObjectError.InspectFormatError;
        for (self.parameters.items, 1..) |param, i| {
            param.debug_string(buf) catch return ObjectError.InspectFormatError;
            if (i != self.parameters.items.len) {
                std.fmt.format(buf.*.writer(), ", ", .{}) catch return ObjectError.InspectFormatError;
            }
        }
        std.fmt.format(buf.*.writer(), "): ", .{}) catch return ObjectError.InspectFormatError;
        self.body.debug_string(buf) catch return ObjectError.InspectFormatError;
        std.fmt.format(buf.*.writer(), " end", .{}) catch return ObjectError.InspectFormatError;
    }
};

pub const Integer = struct {
    type: ObjectType,
    value: i64,

    pub fn inspect(self: Integer, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "{d}", .{self.value}) catch return ObjectError.InspectFormatError;
    }
};

pub const Boolean = struct {
    type: ObjectType,
    value: bool,

    pub fn inspect(self: Boolean, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "{?}", .{self.value}) catch return ObjectError.InspectFormatError;
    }
};

pub const Null = struct {
    type: ObjectType,

    pub fn inspect(_: Null, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "null", .{}) catch return ObjectError.InspectFormatError;
    }
};

pub const Return = struct {
    type: ObjectType,
    value: *const Object,

    pub fn inspect(self: Return, buf: *std.ArrayList(u8)) ObjectError!void {
        try self.value.inspect(buf);
    }
};

pub const Error = struct {
    type: ObjectType,
    msg: []const u8,

    pub fn inspect(self: Error, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "{s}", .{self.msg}) catch return ObjectError.InspectFormatError;
    }
};
