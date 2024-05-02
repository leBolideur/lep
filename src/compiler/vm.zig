const std = @import("std");

const common = @import("common");

const Lexer = common.lexer.Lexer;
const Parser = common.parser.Parser;
const Object = common.object.Object;

const ast = common.ast;
const bytecode_ = @import("bytecode.zig");

const comp_imp = @import("compiler.zig");
const Bytecode = comp_imp.Bytecode;
const Frame = @import("frame.zig").Frame;

const Opcode = @import("opcode.zig").Opcode;

const eval_utils = common.eval_utils;

const stderr = std.io.getStdErr().writer();
const VMError = error{
    OutOfMemory,
    ObjectCreation,
    WrongType,
    DivideByZero,
    InvalidOperation,
    ArrayCreation,
    HashCreation,
    InvalidHashKey,
    BadIndex,
    FrameCreation,
    MissingExpression,
    StackResize,
    StackOverflow,
};

const true_object = eval_utils.new_boolean(true);
const false_object = eval_utils.new_boolean(false);
pub const null_object = eval_utils.new_null();

const STACK_SIZE = 2048;

pub const VM = struct {
    constants: std.ArrayList(*const Object),

    stack: []*const Object,
    sp: usize, // Always point to the next value, top of stack is sp-1
    last_popped: ?*const Object,

    frames: std.ArrayList(*Frame),

    globals: []*const Object,

    alloc: *const std.mem.Allocator,

    pub fn new(alloc: *const std.mem.Allocator, bytecode: Bytecode) VMError!VM {
        const main_fn = eval_utils.new_compiled_func(alloc, bytecode.instructions, 0) catch return VMError.ObjectCreation;

        const main_frame = Frame.new(alloc, main_fn.compiled_func, 0) catch return VMError.FrameCreation;

        var frames = std.ArrayList(*Frame).init(alloc.*);
        frames.append(main_frame) catch return VMError.OutOfMemory;

        const stack = alloc.alloc(*const Object, STACK_SIZE) catch return VMError.OutOfMemory;

        return VM{
            .constants = bytecode.constants,

            .stack = stack,
            .sp = 0,
            .last_popped = null,

            .frames = frames,

            .globals = alloc.*.alloc(*const Object, 65536) catch return VMError.OutOfMemory,

            .alloc = alloc,
        };
    }

    fn current_frame(self: *VM) *Frame {
        return self.frames.getLast();
    }

    fn push_frame(self: *VM, frame: *Frame) VMError!void {
        self.frames.append(frame) catch return VMError.FrameCreation;
    }

    fn pop_frame(self: *VM) *Frame {
        return self.frames.pop();
    }

    pub fn run(self: *VM) VMError!void {
        while (self.current_frame().ip < (self.current_frame().instructions().items.len) - 1) {
            self.current_frame().ip += 1;

            const current_f = self.current_frame();
            const ip = @as(usize, @intCast(current_f.ip));
            var instructions = self.current_frame().instructions();

            const opcode_ = instructions.items[ip];
            const opcode = @as(Opcode, @enumFromInt(opcode_));

            switch (opcode) {
                .OpConstant => {
                    const index = bytecode_.read_u16(instructions.items[(ip + 1)..]);
                    current_f.ip += 2; // Skip the operand just readed

                    const constant_obj = self.constants.items[index];
                    try self.push(constant_obj);
                },
                .OpSetGlobal => {
                    const global_index = bytecode_.read_u16(instructions.items[(ip + 1)..]);
                    current_f.ip += 2;

                    self.globals[global_index] = self.pop().?;
                },
                .OpGetGlobal => {
                    const global_index = bytecode_.read_u16(instructions.items[(ip + 1)..]);
                    current_f.ip += 2;

                    try self.push(self.globals[global_index]);
                },
                .OpSetLocal => {
                    const local_index = bytecode_.read_u8(instructions.items[(ip + 1)..]);
                    current_f.ip += 1;

                    self.stack[current_f.base_pointer + local_index] = self.pop().?;
                },
                .OpGetLocal => {
                    const local_index = bytecode_.read_u8(instructions.items[(ip + 1)..]);
                    current_f.ip += 1;

                    try self.push(self.stack[current_f.base_pointer + local_index]);
                },

                .OpArray => {
                    const array_size = bytecode_.read_u16(instructions.items[(ip + 1)..]);
                    current_f.ip += 2;

                    const array = try self.build_array(array_size);
                    try self.push(array);
                },
                .OpHash => {
                    const hash_size = bytecode_.read_u16(instructions.items[(ip + 1)..]);
                    current_f.ip += 2;

                    const hash = try self.build_hash(hash_size);
                    try self.push(hash);
                },
                .OpIndex => {
                    const index = self.pop().?;
                    const left = self.pop().?;

                    switch (left.*) {
                        .array => {
                            switch (index.*) {
                                .integer => try self.execute_array_index(left, index),
                                else => |other| {
                                    stderr.print("Array must be indexed with Integer only, got: {?}\n", .{other}) catch {};
                                    return VMError.BadIndex;
                                },
                            }
                        },
                        .hash => {
                            switch (index.*) {
                                .string => try self.execute_hash_index(left, index),
                                else => |other| {
                                    stderr.print("Hash must be indexed with String only, got: {?}\n", .{other}) catch {};
                                    return VMError.BadIndex;
                                },
                            }
                        },
                        else => |other| {
                            stderr.print("Indexing is only possible on Array or Hash, got: {?}\n", .{other}) catch {};
                            return VMError.WrongType;
                        },
                    }
                },

                .OpTrue => try self.push(true_object),
                .OpFalse => try self.push(false_object),
                .OpNull => try self.push(null_object),

                .OpAdd, .OpSub, .OpMul, .OpDiv => try self.execute_binary_operation(opcode),

                .OpEq, .OpNotEq, .OpGT => try self.execute_comparison(opcode),
                .OpMinus => try self.execute_minus_operator(),
                .OpBang => try self.execute_bang_operator(),

                .OpPop => {
                    _ = self.pop();
                },

                .OpJumpNotTrue => {
                    const offset = bytecode_.read_u16(instructions.items[(ip + 1)..]);
                    current_f.ip += 2; // Skip the operand just readed

                    const condition_obj = self.pop();
                    switch (condition_obj.?.*) {
                        .boolean => |boo| {
                            if (!boo.value) current_f.ip = offset - 1; // -1 because the while loop increment ip by 1
                        },
                        else => |other| {
                            stderr.print("Expression of a condition must result as a Boolean, got: {?}\n", .{other}) catch {};
                            return VMError.WrongType;
                        },
                    }
                },
                .OpJump => {
                    const offset = bytecode_.read_u16(instructions.items[(ip + 1)..]);
                    current_f.ip = offset - 1; // -1 because the while loop increment ip by 1
                },

                .OpCall => {
                    const compiled_func = self.stack_top().?;
                    switch (compiled_func.*) {
                        .compiled_func => |c_func| {
                            const new_frame = Frame.new(self.alloc, c_func, self.sp) catch return VMError.FrameCreation;
                            try self.push_frame(new_frame);

                            self.sp = new_frame.base_pointer + c_func.locals_count;
                        },
                        else => |other| {
                            stderr.print("Trying to call a non-function object, got: {?}", .{other}) catch {};
                            return VMError.WrongType;
                        },
                    }
                },
                .OpReturnValue => {
                    // the returned value
                    const ret = self.pop();

                    // Return to the caller function
                    const frame = self.pop_frame();
                    // free stack and pop the compiledFunction object
                    self.sp = frame.base_pointer - 1;

                    try self.push(ret.?);
                },
                .OpReturn => {
                    // Return to the caller function
                    const frame = self.pop_frame();
                    // free stack and pop the compiledFunction object
                    self.sp = frame.base_pointer - 1;

                    try self.push(null_object);
                },
            }
        }
    }

    fn execute_array_index(self: *VM, object: *const Object, index: *const Object) VMError!void {
        const array_len = object.array.elements.items.len;

        if (index.integer.value > 0 and index.integer.value < array_len) {
            const idx = @as(usize, @intCast(index.integer.value));
            const elem = object.array.elements.items[idx];
            try self.push(elem);
            return;
        }
        try self.push(null_object);
    }

    fn execute_hash_index(self: *VM, object: *const Object, index: *const Object) VMError!void {
        const idx = index.string.value;
        const elem = object.hash.pairs.get(idx);
        if (elem == null) {
            try self.push(null_object);
            return;
        }
        try self.push(elem.?);
    }

    fn build_array(self: *VM, array_size: usize) VMError!*const Object {
        var popped_values = std.ArrayList(*const Object).init(self.alloc.*);
        for (0..array_size) |_| {
            // Insert at 0 to preserve stack order
            popped_values.insert(0, self.pop().?) catch return VMError.ArrayCreation;
        }

        const array = eval_utils.new_array(self.alloc, popped_values) catch return VMError.ArrayCreation;
        return array;
    }

    fn build_hash(self: *VM, hash_size: usize) VMError!*const Object {
        var popped_values = std.StringHashMap(*const Object).init(self.alloc.*);
        for (0..hash_size) |_| {
            const value = self.pop() orelse eval_utils.new_null();
            const key = self.pop();

            if (key != null) {
                switch (key.?.*) {
                    .string => |string| {
                        popped_values.put(string.value, value) catch return VMError.HashCreation;
                    },
                    else => |other| {
                        stderr.print("Invalid hash key, got: {?}\n", .{other}) catch {};
                        return VMError.InvalidHashKey;
                    },
                }
            }
        }

        const hash = eval_utils.new_hash(self.alloc, popped_values) catch return VMError.HashCreation;
        return hash;
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
                    .integer => try self.execute_bin_integer_op(opcode, left_, right_),
                    else => |other| {
                        stderr.print("Wrong type! Arithmetic operation operands must have the same type, got={?}", .{other}) catch {};
                        return VMError.WrongType;
                    },
                }
            },
            .string => {
                switch (left_.*) {
                    .string => try self.execute_bin_string_op(opcode, left_, right_),
                    else => |other| {
                        stderr.print("Wrong type! Arithmetic operation operands must have the same type, got={?}", .{other}) catch {};
                        return VMError.WrongType;
                    },
                }
            },
            else => |other| {
                stderr.print("Wrong type! Arithmetic operations is only available with Integer and String, got={?}", .{other}) catch {};
                return VMError.WrongType;
            },
        }
    }

    fn execute_bin_integer_op(
        self: *VM,
        opcode: Opcode,
        left_: *const Object,
        right_: *const Object,
    ) VMError!void {
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
            else => {
                stderr.print("Invalid operation on Integers.", .{}) catch {};
                return VMError.InvalidOperation;
            },
        }

        const object = eval_utils.new_integer(self.alloc, result) catch return VMError.ObjectCreation;
        try self.push(object);
    }

    fn execute_bin_string_op(
        self: *VM,
        opcode: Opcode,
        left_: *const Object,
        right_: *const Object,
    ) VMError!void {
        const right = right_.string.value;
        const left = left_.string.value;

        switch (opcode) {
            .OpAdd => {
                const result = std.fmt.allocPrint(self.alloc.*, "{s}{s}", .{ left, right }) catch return VMError.OutOfMemory;
                // const result = left ++ right;
                const object = eval_utils.new_string(self.alloc, result) catch return VMError.ObjectCreation;
                try self.push(object);
            },
            else => {
                stderr.print("Invalid operation on Strings.", .{}) catch {};
                return VMError.InvalidOperation;
            },
        }
    }

    fn execute_comparison(self: *VM, opcode: Opcode) VMError!void {
        // lifo! right pop before
        const right_ = self.pop() orelse return VMError.MissingExpression;
        const left_ = self.pop() orelse return VMError.MissingExpression;

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

    pub fn stack_top(self: VM) ?*const Object {
        if (self.sp == 0) return null;

        return self.stack[self.sp - 1];
    }

    fn push(self: *VM, constant: *const Object) VMError!void {
        if (self.sp >= STACK_SIZE) return VMError.StackOverflow;
        self.stack[self.sp] = constant;
        self.sp += 1;
    }

    pub fn pop(self: *VM) ?*const Object {
        if (self.sp == 0) return null;
        const pop_ = self.stack[self.sp - 1];
        // std.debug.print("pop -- sp >> {d}\tpopped >> {any}\n", .{ self.sp, pop_ });
        self.last_popped = pop_;

        self.sp -= 1;

        return pop_;
    }

    pub fn last_popped_element(self: VM) ?*const Object {
        return self.last_popped;
    }
};
