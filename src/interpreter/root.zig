const std = @import("std");

const ast_test = @import("ast_test.zig");
const eval_test = @import("eval_test.zig");
const parser_test = @import("parser_test.zig");

test {
    std.testing.refAllDecls(@This());
}
