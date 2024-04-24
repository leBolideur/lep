const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // Modules declaration
    const common = b.createModule(.{ .root_source_file = .{ .path = "src/common/mod.zig" } });
    const interpreter = b.createModule(.{ .root_source_file = .{ .path = "src/interpreter/mod.zig" } });
    const compiler = b.createModule(.{ .root_source_file = .{ .path = "src/compiler/mod.zig" } });

    const exe = b.addExecutable(.{
        .name = "lep",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("common", common);
    compiler.addImport("common", common);
    interpreter.addImport("common", common);

    exe.root_module.addImport("interpreter", interpreter);
    common.addImport("interpreter", interpreter);

    exe.root_module.addImport("compiler", compiler);

    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests/run.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.root_module.addImport("common", common);
    unit_tests.root_module.addImport("interpreter", interpreter);
    unit_tests.root_module.addImport("compiler", compiler);

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
