const std = @import("std");

pub const ast = @import("ast_test.zig");
pub const parser = @import("parser_test.zig");
pub const eval = @import("eval_test.zig");
pub const code = @import("code_test.zig");
pub const compiler = @import("compiler_test.zig");
pub const vm = @import("vm_test.zig");

test "Root test all" {
    std.testing.refAllDecls(@This());
}
