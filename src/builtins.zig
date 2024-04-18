const std = @import("std");

const obj_import = @import("object.zig");
const Object = obj_import.Object;

const eval_utils = @import("evaluator_utils.zig");

const BuiltinsError = error{ ArrayCreation, ArrayClone, ArrayAppend };

pub const BuiltinFunction = enum {
    len,
    push,

    pub fn call(self: BuiltinFunction, alloc: *const std.mem.Allocator, args: std.ArrayList(*const Object)) !*const Object {
        return switch (self) {
            .len => try len(alloc, args),
            .push => try push(alloc, args),
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
        .array => |array| array.elements.items.len,
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

pub fn push(alloc: *const std.mem.Allocator, args: std.ArrayList(*const Object)) !*const Object {
    if (args.items.len != 2) {
        return try eval_utils.new_error(
            alloc,
            "wrong number of arguments. got={d}, want={d}",
            .{ args.items.len, 1 },
        );
    }

    const object = args.items[0];
    const element = args.items[1];
    const str_len = switch (object.*) {
        // .string => |string| string.value.len,
        .array => |array| {
            var new = try array.elements.clone();
            try new.append(element);
            return try eval_utils.new_array(alloc, new);
        },
        else => |other| {
            return try eval_utils.new_error(
                alloc,
                "argument to `push` not supported, got {s}",
                .{other.typename()},
            );
        },
    };

    return try eval_utils.new_integer(alloc, @as(i64, @intCast(str_len)));
}
