const std = @import("std");

pub const vm = @import("vm_test.zig");
pub const ast = @import("ast_test.zig");
pub const code = @import("code_test.zig");
pub const compiler = @import("compiler_test.zig");
pub const parser = @import("parser_test.zig");
pub const eval = @import("eval_test.zig");
pub const symbol_table = @import("symbol_table_test.zig");

test "Run all the tests" {
    std.testing.refAllDecls(@This());
}
