const std = @import("std");

const Lexer = @import("../interpreter/lexer/lexer.zig").Lexer;
const Parser = @import("../interpreter/parser/parser.zig").Parser;
const Object = @import("../interpreter/intern/object.zig").Object;

const ast = @import("../interpreter/ast/ast.zig");
const code = @import("code.zig");

const comp_imp = @import("compiler.zig");
const Bytecode = comp_imp.Bytecode;

const eval_utils = @import("../interpreter/utils/eval_utils.zig");

const VMError = error{ OutOfMemory, ObjectCreation };

pub const VM = struct {
    instructions: std.ArrayList(u8),
    constants: std.ArrayList(*const Object),

    stack: std.ArrayList(*const Object),
    last_popped: ?*const Object,
    sp: usize, // always point to the next free slot

    alloc: *const std.mem.Allocator,

    pub fn new(alloc: *const std.mem.Allocator, bytecode: Bytecode) VM {
        return VM{
            .instructions = bytecode.instructions.instructions,
            .constants = bytecode.constants,

            .stack = std.ArrayList(*const Object).init(alloc.*),
            .last_popped = null,
            .sp = 0,

            .alloc = alloc,
        };
    }

    pub fn run(self: *VM) VMError!void {
        var ip: usize = 0;

        const instr_ = try self.instructions.toOwnedSlice();
        while (ip < instr_.len) : (ip += 1) {
            const opcode_ = instr_[ip];
            const opcode = @as(code.Opcode, @enumFromInt(opcode_));

            switch (opcode) {
                .OpConstant => {
                    const index = code.read_u16(instr_[(ip + 1)..]);
                    ip += 2;

                    const constant_obj = self.constants.items[index];
                    try self.push(constant_obj);
                },
                .OpAdd => {
                    const right = self.pop().?.integer.value; // lifo! right pop before
                    const left = self.pop().?.integer.value;

                    const result = eval_utils.new_integer(self.alloc, left + right) catch return VMError.ObjectCreation;
                    try self.push(result);
                },
                .OpPop => {
                    _ = self.pop();
                },
            }
        }
    }

    fn push(self: *VM, constant: *const Object) VMError!void {
        try self.stack.append(constant);
        self.sp += 1;
    }

    pub fn stack_top(self: VM) ?*const Object {
        const last = self.stack.getLastOrNull();
        return last;
    }

    pub fn pop(self: *VM) ?*const Object {
        const pop_ = self.stack.popOrNull();
        self.sp -= 1;
        self.last_popped = pop_;
        return pop_;
    }

    pub fn last_popped_element(self: VM) ?*const Object {
        return self.last_popped;
    }
};
