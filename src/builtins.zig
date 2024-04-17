const std = @import("std");

const obj_import = @import("object.zig");
const BuiltinObject = obj_import.BuiltinObject;
const Object = obj_import.Object;

const eval_utils = @import("evaluator_utils.zig");

pub const len_builtin = BuiltinObject{ .function = BuiltinFunction.len };

pub const BuiltinFunction = enum {
    len,

    pub fn call(self: BuiltinFunction, alloc: *const std.mem.Allocator, args: std.ArrayList(*const Object)) !*const Object {
        return switch (self) {
            .len => try len(alloc, args),
        };
    }
};

pub fn len(alloc: *const std.mem.Allocator, args: std.ArrayList(*const Object)) !*const Object {
    if (args.items.len > 1) {
        return try eval_utils.new_error(
            alloc,
            "wrong number of arguments. got={d}, want={d}",
            .{ args.items.len, 1 },
        );
    }

    const object = args.items[0];
    const str_len = switch (object.*) {
        .string => |string| string.value.len,
        else => |other| {
            return try eval_utils.new_error(
                alloc,
                "argument to `len` not supported, got {s}",
                .{other.typename()},
            );
        },
    };

    return try eval_utils.new_integer(alloc, @as(i64, @intCast(str_len)));
}
