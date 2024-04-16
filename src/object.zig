const std = @import("std");

const ast = @import("ast.zig");
const Environment = @import("environment.zig").Environment;

pub const ObjectType = union(enum) { Integer, Boolean, Null, Return, Error, NamedFunc, LiteralFunc };

pub const ObjectError = error{InspectFormatError};

pub const Object = union(enum) {
    integer: Integer,
    boolean: Boolean,
    null: Null,
    ret: Return,
    err: Error,
    literal_func: LiteralFunc,
    named_func: NamedFunc,

    pub fn inspect(self: Object, buf: *std.ArrayList(u8)) ObjectError!void {
        try switch (self) {
            .integer => |integer| integer.inspect(buf),
            .boolean => |boolean| boolean.inspect(buf),
            .null => |n| n.inspect(buf),
            .ret => |ret| ret.inspect(buf),
            .err => |err| err.inspect(buf),
            .literal_func => |func| func.inspect(buf),
            .named_func => |func| func.inspect(buf),
        };
    }

    pub fn typename(self: Object) []const u8 {
        return switch (self) {
            .integer => "Integer",
            .boolean => "Boolean",
            .null => "Null",
            .ret => "Ret",
            .err => "Error",
            .literal_func => "Literal Func",
            .named_func => "Named Func",
        };
    }
};

pub const Func = union(enum) {
    named: NamedFunc,
    literal: LiteralFunc,

    pub fn inspect(self: Func, buf: *std.ArrayList(u8)) ObjectError!void {
        try switch (self) {
            .named => |f| f.inspect(buf),
            .literal => |f| f.inspect(buf),
        };
    }
};

pub const LiteralFunc = struct {
    type: ObjectType,
    // name: []const u8,
    parameters: std.ArrayList(ast.Identifier),
    body: ast.BlockStatement,
    env: *const Environment,

    pub fn inspect(self: LiteralFunc, buf: *std.ArrayList(u8)) ObjectError!void {
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

pub const NamedFunc = struct {
    type: ObjectType,
    name: []const u8,
    parameters: std.ArrayList(ast.Identifier),
    body: ast.BlockStatement,
    env: *const Environment,

    pub fn inspect(self: NamedFunc, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "fn {s}(", .{self.name}) catch return ObjectError.InspectFormatError;
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
