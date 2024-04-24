const std = @import("std");

const common = @import("common");

const obj_import = common.object;
const Object = obj_import.Object;

const eval_utils = common.eval_utils;

const BuiltinsError = error{ ArrayCreation, ArrayClone, ArrayAppend };

pub const BuiltinFunction = enum {
    len,
    push,
    head,
    last,
    tail,
    print,

    pub fn call(self: BuiltinFunction, alloc: *const std.mem.Allocator, args: std.ArrayList(*const Object)) !*const Object {
        return switch (self) {
            .len => try len(alloc, args),
            .push => try push(alloc, args),
            .head => try head(alloc, args),
            .last => try last(alloc, args),
            .tail => try tail(alloc, args),
            .print => try print(alloc, args),
        };
    }
};

pub fn print(alloc: *const std.mem.Allocator, args: std.ArrayList(*const Object)) !*const Object {
    if (args.items.len == 0) {
        return try eval_utils.new_error(
            alloc,
            "wrong number of arguments. got=0",
            .{},
        );
    }

    const stdout = std.io.getStdOut().writer();
    var buf = std.ArrayList(u8).init(alloc.*);
    defer buf.deinit();

    for (args.items) |object| {
        switch (object.*) {
            .string,
            .array,
            .integer,
            .boolean,
            => {
                try object.*.inspect(&buf);
                const str = buf.toOwnedSlice() catch "";
                stdout.print("{s}", .{str}) catch {};
            },
            else => |other| {
                return try eval_utils.new_error(
                    alloc,
                    "argument to `print` not supported, got {s}",
                    .{other.typename()},
                );
            },
        }
    }

    stdout.print("\n", .{}) catch {};
    return eval_utils.new_null();
}

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

pub fn head(alloc: *const std.mem.Allocator, args: std.ArrayList(*const Object)) !*const Object {
    if (args.items.len > 1) {
        return try eval_utils.new_error(
            alloc,
            "wrong number of arguments. got={d}, want={d}",
            .{ args.items.len, 1 },
        );
    }

    const object = args.items[0];
    switch (object.*) {
        // .string => |string| string.value.len,
        .array => |array| {
            if (array.elements.items.len == 0) {
                return try eval_utils.new_error(
                    alloc,
                    "`head` is not applicable on empty array.",
                    .{},
                );
            }
            return array.elements.items[0];
        },
        else => |other| {
            return try eval_utils.new_error(
                alloc,
                "argument to `head` not supported, got {s}",
                .{other.typename()},
            );
        },
    }
}

pub fn last(alloc: *const std.mem.Allocator, args: std.ArrayList(*const Object)) !*const Object {
    if (args.items.len > 1) {
        return try eval_utils.new_error(
            alloc,
            "wrong number of arguments. got={d}, want={d}",
            .{ args.items.len, 1 },
        );
    }

    const object = args.items[0];
    switch (object.*) {
        // .string => |string| string.value.len,
        .array => |array| {
            if (array.elements.items.len == 0) {
                return try eval_utils.new_error(
                    alloc,
                    "`last` is not applicable on empty array.",
                    .{},
                );
            }
            const array_len = array.elements.items.len;
            return array.elements.items[array_len - 1];
        },
        else => |other| {
            return try eval_utils.new_error(
                alloc,
                "argument to `last` not supported, got {s}",
                .{other.typename()},
            );
        },
    }
}

pub fn tail(alloc: *const std.mem.Allocator, args: std.ArrayList(*const Object)) !*const Object {
    if (args.items.len > 1) {
        return try eval_utils.new_error(
            alloc,
            "wrong number of arguments. got={d}, want={d}",
            .{ args.items.len, 1 },
        );
    }

    const object = args.items[0];
    switch (object.*) {
        // .string => |string| string.value.len,
        .array => |array| {
            if (array.elements.items.len == 0) {
                return try eval_utils.new_error(
                    alloc,
                    "`tail` is not applicable on empty array.",
                    .{},
                );
            }
            var new = std.ArrayList(*const Object).init(alloc.*);
            var i: usize = 1;
            while (i < array.elements.items.len) : (i += 1) {
                try new.append(array.elements.items[i]);
            }
            return try eval_utils.new_array(alloc, new);
        },
        else => |other| {
            return try eval_utils.new_error(
                alloc,
                "argument to `tail` not supported, got {s}",
                .{other.typename()},
            );
        },
    }
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
