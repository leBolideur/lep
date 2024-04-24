const std = @import("std");

const obj_import = @import("object");
const Object = obj_import.Object;
const Integer = obj_import.Integer;
const String = obj_import.String;
const Array = obj_import.Array;
const Hash = obj_import.Hash;
const Null = obj_import.Null;
const Boolean = obj_import.Boolean;
const Return = obj_import.Return;
const Error = obj_import.Error;
const Func = obj_import.Func;
const NamedFunc = obj_import.NamedFunc;
const LiteralFunc = obj_import.LiteralFunc;
const ObjectType = obj_import.ObjectType;
const BuiltinObject = obj_import.BuiltinObject;

const Environment = @import("environment").Environment;

const BuiltinFunction = @import("builtins").BuiltinFunction;

const ast = @import("ast");

pub const EvalError = error{ BadNode, MemAlloc, EnvAddError, EnvGetError, EnvExtendError, BuiltinCall };

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
    const ptr = allocator.create(Object) catch return EvalError.MemAlloc;

    const result = Integer{ .type = ObjectType.Integer, .value = value };
    ptr.* = Object{ .integer = result };

    return ptr;
}

pub fn new_string(allocator: *const std.mem.Allocator, value: []const u8) !*const Object {
    const ptr = allocator.create(Object) catch return EvalError.MemAlloc;

    const result = String{ .type = ObjectType.String, .value = value };
    ptr.* = Object{ .string = result };

    return ptr;
}

pub fn new_array(
    allocator: *const std.mem.Allocator,
    elements: std.ArrayList(*const Object),
) !*const Object {
    const ptr = allocator.create(Object) catch return EvalError.MemAlloc;

    const result = Array{ .type = ObjectType.String, .elements = elements };
    ptr.* = Object{ .array = result };

    return ptr;
}

pub fn new_hash(
    allocator: *const std.mem.Allocator,
    pairs: std.StringHashMap(*const Object),
) !*const Object {
    const ptr = allocator.create(Object) catch return EvalError.MemAlloc;

    const result = Hash{ .type = ObjectType.String, .pairs = pairs };
    ptr.* = Object{ .hash = result };

    return ptr;
}

pub fn new_builtin(allocator: *const std.mem.Allocator, function: BuiltinFunction) !*const Object {
    const ptr = allocator.create(Object) catch return EvalError.MemAlloc;

    const result = BuiltinObject{ .type = ObjectType.Builtin, .function = function };
    ptr.* = Object{ .builtin = result };

    return ptr;
}

pub fn new_func(
    allocator: *const std.mem.Allocator,
    env: *const Environment,
    func: ast.Function,
) !*const Object {
    const ptr = allocator.create(Object) catch return EvalError.MemAlloc;

    switch (func) {
        .named => |named| {
            const named_func = NamedFunc{
                .type = ObjectType.NamedFunc,
                .name = named.name.value,
                .parameters = named.func_literal.parameters,
                .body = named.func_literal.body,
                .env = env,
            };
            ptr.* = Object{ .named_func = named_func };
        },
        .literal => |f| {
            const lit = LiteralFunc{
                .type = ObjectType.LiteralFunc,
                .parameters = f.parameters,
                .body = f.body,
                .env = env,
            };
            ptr.* = Object{ .literal_func = lit };
        },
    }

    return ptr;
}

pub fn new_return(allocator: *const std.mem.Allocator, object: *const Object) !*const Object {
    const ptr = allocator.create(Object) catch return EvalError.MemAlloc;
    const ret = Return{ .type = ObjectType.Return, .value = object };
    ptr.* = Object{ .ret = ret };

    return ptr;
}

pub fn new_error(
    allocator: *const std.mem.Allocator,
    comptime fmt: []const u8,
    args: anytype,
) !*const Object {
    const msg = std.fmt.allocPrint(allocator.*, fmt, args) catch return EvalError.MemAlloc;
    const ptr = allocator.create(Object) catch return EvalError.MemAlloc;
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

pub fn is_error(object: *const Object) bool {
    return switch (object.*) {
        .err => true,
        else => false,
    };
}
