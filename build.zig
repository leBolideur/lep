const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "lep",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const token = b.createModule(.{ .root_source_file = .{ .path = "src/interpreter/token.zig" } });
    const lexer = b.createModule(.{
        .root_source_file = .{ .path = "src/common/lexer.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "token", .module = token },
        },
    });
    const ast = b.createModule(.{
        .root_source_file = .{ .path = "src/common/ast.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "token", .module = token },
        },
    });
    const object = b.createModule(.{
        .root_source_file = .{ .path = "src/common/object.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "ast", .module = ast },
        },
    });
    const parser = b.createModule(.{
        .root_source_file = .{ .path = "src/common/parser.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "token", .module = token },
            .{ .name = "ast", .module = ast },
            .{ .name = "lexer", .module = lexer },
        },
    });
    const environment = b.createModule(.{
        .root_source_file = .{ .path = "src/interpreter/environment.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "object", .module = object },
            .{ .name = "ast", .module = ast },
        },
    });
    object.addImport("environment", environment);
    const opcode = b.createModule(.{
        .root_source_file = .{ .path = "src/compiler/opcode.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "object", .module = object },
        },
    });
    const bytecode = b.createModule(.{
        .root_source_file = .{ .path = "src/compiler/bytecode.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "object", .module = object },
            .{ .name = "opcode", .module = opcode },
        },
    });
    const builtins = b.createModule(.{
        .root_source_file = .{ .path = "src/interpreter/builtins.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "object", .module = object },
        },
    });
    object.addImport("builtins", builtins);
    const compiler = b.createModule(.{
        .root_source_file = .{ .path = "src/compiler/compiler.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "ast", .module = ast },
            .{ .name = "object", .module = object },
            .{ .name = "parser", .module = parser },
            .{ .name = "bytecode", .module = bytecode },
            .{ .name = "opcode", .module = opcode },
        },
    });
    const vm = b.createModule(.{
        .root_source_file = .{ .path = "src/compiler/vm.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "object", .module = object },
            // .{ .name = "environment", .module = environment },
            .{ .name = "bytecode", .module = bytecode },
            .{ .name = "opcode", .module = opcode },
            .{ .name = "compiler", .module = compiler },
            // .{ .name = "builtins", .module = builtins },
        },
    });
    const eval_utils = b.createModule(.{
        .root_source_file = .{ .path = "src/common/eval_utils.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "object", .module = object },
            .{ .name = "builtins", .module = builtins },
            .{ .name = "environment", .module = environment },
            .{ .name = "ast", .module = ast },
            // .{ .name = "bytecode", .module = bytecode },
            // .{ .name = "opcode", .module = opcode },
            // .{ .name = "vm", .module = vm },
        },
    });
    compiler.addImport("eval_utils", eval_utils);
    vm.addImport("eval_utils", eval_utils);
    builtins.addImport("eval_utils", eval_utils);
    const evaluator = b.createModule(.{
        .root_source_file = .{ .path = "src/interpreter/evaluator.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "object", .module = object },
            .{ .name = "environment", .module = environment },
            .{ .name = "builtins", .module = builtins },
            .{ .name = "ast", .module = ast },
            // .{ .name = "bytecode", .module = bytecode },
            // .{ .name = "opcode", .module = opcode },
            // .{ .name = "vm", .module = vm },
            .{ .name = "eval_utils", .module = eval_utils },
        },
    });

    // exe.root_module.addAnonymousImport("ast", ast);

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
        .root_source_file = .{ .path = "src/tests/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.root_module.addImport("ast", ast);
    unit_tests.root_module.addImport("token", token);
    unit_tests.root_module.addImport("lexer", lexer);
    unit_tests.root_module.addImport("object", object);
    unit_tests.root_module.addImport("parser", parser);
    unit_tests.root_module.addImport("environment", environment);
    unit_tests.root_module.addImport("opcode", opcode);
    unit_tests.root_module.addImport("bytecode", bytecode);
    unit_tests.root_module.addImport("builtins", builtins);
    unit_tests.root_module.addImport("compiler", compiler);
    unit_tests.root_module.addImport("vm", vm);
    unit_tests.root_module.addImport("eval_utils", eval_utils);
    unit_tests.root_module.addImport("evaluator", evaluator);
    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
