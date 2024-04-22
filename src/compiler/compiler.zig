const std = @import("std");

const ast = @import("../interpreter/ast/ast.zig");
const object = @import("../interpreter/intern/object.zig");

const code = @import("code.zig");

const Bytecode = struct {
    instructions: code.Instructions,
    constants: std.ArrayList(object.Object),
};

pub const Compiler = struct {
    instructions: code.Instructions,
    constants: std.ArrayList(object.Object),

    pub fn init(alloc: *const std.mem.Allocator) Compiler {
        var constants = std.ArrayList(object.Object).init(alloc.*);

        return Compiler{
            .instructions = code.Instructions{ .instructions = "" },
            .constants = constants,
        };
    }

    pub fn compile(self: Compiler, node: ast.Node) !void {
        _ = self;
        _ = node;
    }

    pub fn bytecode(self: Compiler) Bytecode {
        return Bytecode{
            .instructions = self.instructions,
            .constants = self.constants,
        };
    }
};
