const std = @import("std");

const common = @import("common");

const Lexer = common.lexer.Lexer;
const Parser = common.parser.Parser;
const Object = common.object.Object;

const ast = common.ast;
const bytecode_ = @import("bytecode.zig");

const comp_imp = @import("compiler.zig");
const Bytecode = comp_imp.Bytecode;

const Opcode = @import("opcode.zig").Opcode;

const eval_utils = common.eval_utils;

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
                    ip += 2; // Skip the operand just readed

                    const constant_obj = self.constants.items[index];
                    try self.push(constant_obj);
                },
                .OpTrue => try self.push(true_object),
                .OpFalse => try self.push(false_object),
                .OpAdd, .OpSub, .OpMul, .OpDiv => try self.execute_binary_operation(opcode),

                .OpEq, .OpNotEq, .OpGT => try self.execute_comparison(opcode),
                .OpMinus => try self.execute_minus_operator(),
                .OpBang => try self.execute_bang_operator(),
                .OpPop => {
                    _ = self.pop();
                },
                .OpJumpNotTrue => {
                    const offset = bytecode_.read_u16(instr_[(ip + 1)..]);
                    ip += 2; // Skip the operand just readed

                    const condition_obj = self.pop();
                    switch (condition_obj.?.*) {
                        .boolean => |boo| {
                            if (!boo.value) ip = offset - 1; // -1 because the while loop increment ip by 1
                        },
                        else => |other| {
                            stderr.print("Expression of a condition must result as a Boolean, got: {?}\n", .{other}) catch {};
                            return VMError.WrongType;
                        },
                    }
                },
                .OpJump => {
                    const offset = bytecode_.read_u16(instr_[(ip + 1)..]);
                    ip = offset - 1; // -1 because the while loop increment ip by 1
                },
            }
        }
    }

    fn execute_bang_operator(self: *VM) VMError!void {
        const right = self.pop().?;

        switch (right.*) {
            .boolean => |boo| {
                if (boo.value == true) {
                    try self.push(false_object);
                } else {
                    try self.push(true_object);
                }
            },
            else => |other| {
                stderr.print("Bang operator only works with Boolean, got: {?}\n", .{other}) catch {};
                return VMError.WrongType;
            },
        }
    }

    fn execute_minus_operator(self: *VM) VMError!void {
        const right = self.pop().?;

        switch (right.*) {
            .integer => |int| {
                const minus_int = eval_utils.new_integer(self.alloc, -int.value) catch return VMError.ObjectCreation;
                try self.push(minus_int);
            },
            else => |other| {
                stderr.print("Minus operator only works with Integer, got: {?}\n", .{other}) catch {};
                return VMError.WrongType;
            },
        }
    }

    fn execute_binary_operation(self: *VM, opcode: Opcode) VMError!void {
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

    fn execute_comparison(self: *VM, opcode: Opcode) VMError!void {
        const right_ = self.pop().?; // lifo! right pop before
        const left_ = self.pop().?;

        switch (right_.*) {
            .integer => {
                switch (left_.*) {
                    .integer => return try self.execute_integer_comparison(opcode, left_, right_),
                    else => |other| {
                        stderr.print("Wrong type! Comparison operation operands must have the same type, got={?}", .{other}) catch {};
                        return VMError.WrongType;
                    },
                }
            },
            .boolean => {
                switch (left_.*) {
                    .boolean => {
                        const right = right_.boolean.value;
                        const left = left_.boolean.value;

                        const object = switch (opcode) {
                            .OpEq => if (left == right) true_object else false_object,
                            .OpNotEq => if (left != right) true_object else false_object,
                            else => unreachable,
                        };
                        try self.push(object);
                    },
                    else => |other| {
                        stderr.print("Wrong type! Comparison operation operands must have the same type, got={?}", .{other}) catch {};
                        return VMError.WrongType;
                    },
                }
            },
            else => |other| {
                stderr.print("Wrong type! Comparison operations is only available with Integer and Boolean, got={?}", .{other}) catch {};
                return VMError.WrongType;
            },
        }

        // const right = right_.integer.value;
        // const left = left_.integer.value;

        // const object = switch (opcode) {
        //     .OpEq => if (left == right) true_object else false_object,
        //     .OpNotEq => if (left != right) true_object else false_object,
        //     .OpGT => if (left > right) true_object else false_object,

        //     else => unreachable,
        // };

        // const object = eval_utils.new_boolean(result);
        // try self.push(object);
    }

    fn execute_integer_comparison(
        self: *VM,
        opcode: Opcode,
        left_: *const Object,
        right_: *const Object,
    ) VMError!void {
        const left = left_.integer.value;
        const right = right_.integer.value;

        const object = switch (opcode) {
            .OpEq => if (left == right) true_object else false_object,
            .OpNotEq => if (left != right) true_object else false_object,
            .OpGT => if (left > right) true_object else false_object,

            else => unreachable,
        };

        try self.push(object);
    }

    fn push(self: *VM, constant: *const Object) VMError!void {
        try self.stack.append(constant);
        // self.sp += 1;
    }

    pub fn stack_top(self: VM) ?*const Object {
        const last = self.stack.getLastOrNull();
        return last;
    }

    pub fn pop(self: *VM) ?*const Object {
        const pop_ = self.stack.popOrNull();
        // self.sp -= 1;
        self.last_popped = pop_;
        return pop_;
    }

    pub fn last_popped_element(self: VM) ?*const Object {
        return self.last_popped;
    }
};
