const std = @import("std");

const common = @import("common");
const object = common.object;
const CompiledFunc = object.CompiledFunc;

const FrameError = error{ MemAlloc, BadType };

const stderr = std.io.getStdErr().writer();

pub const Frame = struct {
    func: CompiledFunc,
    ip: isize,
    base_pointer: usize,

    pub fn new(alloc: *const std.mem.Allocator, func: object.CompiledFunc, base_pointer: usize) FrameError!*Frame {
        const ptr = alloc.create(Frame) catch return FrameError.MemAlloc;

        ptr.* = Frame{
            .func = func,
            .ip = -1,
            .base_pointer = base_pointer,
        };

        return ptr;
    }

    pub fn instructions(self: *Frame) std.ArrayList(u8) {
        return self.func.instructions;
    }
};
