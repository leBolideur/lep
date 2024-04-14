const std = @import("std");

const obj_import = @import("object.zig");
const Object = obj_import.Object;
const Integer = obj_import.Integer;
const Null = obj_import.Null;
const Boolean = obj_import.Boolean;
const Return = obj_import.Return;
const Error = obj_import.Error;
const ObjectType = obj_import.ObjectType;

pub const EvalError = error{ BadNode, MemAlloc };

pub const TRUE = Object{
    .boolean = Boolean{
        .type = ObjectType.Boolean,
        .value = true,
    },
};
pub const FALSE = Object{
    .boolean = Boolean{
        .type = ObjectType.Boolean,
        .value = false,
    },
};
pub const NULL = Object{
    .null = Null{
        .type = ObjectType.Null,
    },
};

pub fn new_integer(allocator: *const std.mem.Allocator, value: i64) !*const Object {
    var ptr = allocator.create(Object) catch return EvalError.MemAlloc;

    const result = Integer{ .type = ObjectType.Integer, .value = value };
    ptr.* = Object{ .integer = result };

    return ptr;
}

pub fn new_return(allocator: *const std.mem.Allocator, object: *const Object) !*const Object {
    var ptr = allocator.create(Object) catch return EvalError.MemAlloc;
    const ret = Return{ .type = ObjectType.Return, .value = object };
    ptr.* = Object{ .ret = ret };

    return ptr;
}

pub fn new_error(allocator: *const std.mem.Allocator, comptime fmt: []const u8, args: anytype) !*const Object {
    // _ = fmt;
    // _ = args;
    // const msg = "";
    const msg = std.fmt.allocPrint(allocator.*, fmt, args) catch return EvalError.MemAlloc;
    var ptr = allocator.create(Object) catch return EvalError.MemAlloc;
    const err = Error{ .type = ObjectType.Error, .msg = msg };
    ptr.* = Object{ .err = err };

    return ptr;
}

pub fn new_boolean(value: bool) *const Object {
    if (value) return &TRUE;
    return &FALSE;
}

pub fn new_null() *const Object {
    return &NULL;
}
