const std = @import("std");

const Lexer = @import("../interpreter/lexer/lexer.zig").Lexer;
const Parser = @import("../interpreter/parser/parser.zig").Parser;
const Object = @import("../interpreter/intern/object.zig").Object;

const ast = @import("../interpreter/ast/ast.zig");
const bytecode_ = @import("bytecode.zig");

const comp_imp = @import("compiler.zig");
const Bytecode = comp_imp.Bytecode;

const Opcode = @import("opcode.zig").Opcode;

const eval_utils = @import("../interpreter/utils/eval_utils.zig");

const stderr = std.io.getStdErr().writer();
const VMError = error{ OutOfMemory, ObjectCreation, WrongType, DivideByZero };

const true_object = eval_utils.new_boolean(true);
const false_object = eval_utils.new_boolean(false);

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
            const opcode = @as(Opcode, @enumFromInt(opcode_));

            switch (opcode) {
                .OpConstant => {
                    const index = bytecode_.read_u16(instr_[(ip + 1)..]);
                    ip += 2;

                    const constant_obj = self.constants.items[index];
                    try self.push(constant_obj);
                },
                .OpTrue => try self.push(true_object),
                .OpFalse => try self.push(false_object),
                .OpAdd, .OpSub, .OpMul, .OpDiv => {
                    try self.execure_binary_operation(opcode);
                },
                .OpPop => {
                    _ = self.pop();
                },
            }
        }
    }

    fn execure_binary_operation(self: *VM, opcode: Opcode) VMError!void {
        const right_ = self.pop().?; // lifo! right pop before
        const left_ = self.pop().?;

        switch (right_.*) {
            .integer => {
                switch (left_.*) {
                    .integer => {},
                    else => |other| {
                        stderr.print("Wrong type! Arithmetic operation operands must have the same type, got={?}", .{other}) catch {};
                        return VMError.WrongType;
                    },
                }
            },
            else => |other| {
                stderr.print("Wrong type! Arithmetic operations is only available with Integer, got={?}", .{other}) catch {};
                return VMError.WrongType;
            },
        }

        const right = right_.integer.value;
        const left = left_.integer.value;

        var result: isize = undefined;
        switch (opcode) {
            .OpAdd => result = left + right,
            .OpSub => result = left - right,
            .OpMul => result = left * right,
            .OpDiv => {
                if (right == 0) {
                    stderr.print("Impossible division by zero.", .{}) catch {};
                    return VMError.DivideByZero;
                }
                result = @divFloor(left, right);
            },
            else => unreachable,
        }

        const object = eval_utils.new_integer(self.alloc, result) catch return VMError.ObjectCreation;
        try self.push(object);
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
