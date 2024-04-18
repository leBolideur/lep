const std = @import("std");

const repl = @import("interpreter/repl.zig");

pub fn main() !void {
    try repl.repl();
}
