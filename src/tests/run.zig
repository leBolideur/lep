const std = @import("std");

pub const vm = @import("vm_test.zig");

test "Run all the tests" {
    std.testing.refAllDecls(@This());
}
