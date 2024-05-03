const std = @import("std");

const interpreter = @import("interpreter");
const compiler_ = @import("compiler");

const ast = @import("ast.zig");
const Environment = interpreter.environment.Environment;
const Instructions = compiler_.bytecode.Instructions;

const builtins = interpreter.builtins;

pub const ObjectType = union(enum) {
    Integer,
    Boolean,
    String,
    Array,
    Hash,
    Null,
    Return,
    Error,
    NamedFunc,
    LiteralFunc,
    CompiledFunc,
    Builtin,
};

pub const ObjectError = error{ InspectFormatError, MemAlloc };

pub const Object = union(enum) {
    integer: Integer,
    boolean: Boolean,
    string: String,
    array: Array,
    hash: Hash,
    null: Null,
    ret: Return,
    err: Error,
    literal_func: LiteralFunc,
    named_func: NamedFunc,
    compiled_func: CompiledFunc,
    builtin: BuiltinObject,

    pub fn inspect(self: Object, buf: *std.ArrayList(u8)) ObjectError!void {
        try switch (self) {
            .integer => |integer| integer.inspect(buf),
            .boolean => |boolean| boolean.inspect(buf),
            .string => |string| string.inspect(buf),
            .array => |array| array.inspect(buf),
            .hash => |hash| hash.inspect(buf),
            .null => |null_| null_.inspect(buf),
            .ret => |ret| ret.inspect(buf),
            .err => |err| err.inspect(buf),
            .literal_func => |func| func.inspect(buf),
            .named_func => |func| func.inspect(buf),
            .compiled_func => |func| func.inspect(buf),
            .builtin => |builtin| builtin.inspect(buf),
        };
    }

    pub fn typename(self: Object) []const u8 {
        return switch (self) {
            .integer => "Integer",
            .boolean => "Boolean",
            .string => "String",
            .array => "Array",
            .hash => "Hash",
            .null => "Null",
            .ret => "Ret",
            .err => "Error",
            .literal_func => "Literal Func",
            .named_func => "Named Func",
            .compiled_func => "Compiled Func",
            .builtin => "Builtin function",
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

pub const CompiledFunc = struct {
    type: ObjectType,
    // name: []const u8,
    instructions: std.ArrayList(u8),
    locals_count: usize,
    params_count: usize,

    pub fn inspect(_: CompiledFunc, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "CompiledFunc", .{}) catch return ObjectError.InspectFormatError;
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

pub const BuiltinObject = struct {
    type: ObjectType,
    function: builtins.BuiltinFunction,

    pub fn inspect(_: BuiltinObject, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "builtin function", .{}) catch return ObjectError.InspectFormatError;
    }
};

pub const Integer = struct {
    type: ObjectType,
    value: i64,

    pub fn inspect(self: Integer, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "{d}", .{self.value}) catch return ObjectError.InspectFormatError;
    }
};

pub const String = struct {
    type: ObjectType,
    value: []const u8,

    pub fn inspect(self: String, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "{s}", .{self.value}) catch return ObjectError.InspectFormatError;
    }
};

pub const Array = struct {
    type: ObjectType,
    elements: std.ArrayList(*const Object),

    pub fn inspect(self: Array, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "[", .{}) catch return ObjectError.InspectFormatError;
        for (self.elements.items, 1..) |param, i| {
            param.inspect(buf) catch return ObjectError.InspectFormatError;
            if (i != self.elements.items.len) {
                std.fmt.format(buf.*.writer(), ", ", .{}) catch return ObjectError.InspectFormatError;
            }
        }
        std.fmt.format(buf.*.writer(), " ];", .{}) catch return ObjectError.InspectFormatError;
    }
};

pub const Hash = struct {
    type: ObjectType,
    pairs: std.StringHashMap(*const Object),

    pub fn inspect(self: Hash, buf: *std.ArrayList(u8)) ObjectError!void {
        std.fmt.format(buf.*.writer(), "{{", .{}) catch return ObjectError.InspectFormatError;

        const len = self.pairs.count();
        var iter = self.pairs.iterator();
        var i: u64 = 0;
        while (iter.next()) |item| : (i += 1) {
            const key = item.key_ptr.*;
            const value = item.value_ptr.*;

            std.fmt.format(buf.*.writer(), "{s}: ", .{key}) catch return ObjectError.InspectFormatError;
            try value.inspect(buf);

            if (i != len - 1) {
                std.fmt.format(buf.*.writer(), ", ", .{}) catch return ObjectError.InspectFormatError;
            }
        }

        std.fmt.format(buf.*.writer(), "}}", .{}) catch return ObjectError.InspectFormatError;
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
