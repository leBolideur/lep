const std = @import("std");

const common = @import("common");
const object = common.object;
const CompiledFunc = object.CompiledFunc;

const FrameError = error{ MemAlloc, BadType };

const stderr = std.io.getStdErr().writer();

pub const Frame = struct {
    func: *const CompiledFunc,
    ip: usize,

    pub fn new(func: *const object.Object) FrameError!Frame {
        switch (func.*) {
            .compiled_func => |cmp_func| {
                return Frame{
                    .func = &cmp_func,
                    .ip = 0,
                };
            },
            else => |other| {
                stderr.print("Init frame with non CompiledFunc object, got: {?}\n", .{other}) catch {};

                return FrameError.BadType;
            },
        }
    }

    pub fn instructions(self: Frame) std.ArrayList(u8) {
        return self.func.*.instructions;
    }
};
