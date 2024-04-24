const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

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
            .{ .name = "bytecode", .module = bytecode },
            .{ .name = "opcode", .module = opcode },
            .{ .name = "compiler", .module = compiler },
        },
    });
    const eval_utils = b.createModule(.{
        .root_source_file = .{ .path = "src/common/eval_utils.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "object", .module = object },
            .{ .name = "builtins", .module = builtins },
            .{ .name = "environment", .module = environment },
            .{ .name = "ast", .module = ast },
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
            .{ .name = "eval_utils", .module = eval_utils },
        },
    });
    const repl = b.createModule(.{
        .root_source_file = .{ .path = "src/interpreter/repl.zig" },
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "lexer", .module = lexer },
            .{ .name = "parser", .module = parser },
            .{ .name = "compiler", .module = compiler },
            .{ .name = "environment", .module = environment },
            .{ .name = "vm", .module = vm },
            .{ .name = "ast", .module = ast },
            .{ .name = "evaluator", .module = evaluator },
        },
    });
    // const root = b.createModule(.{
    //     .root_source_file = .{ .path = "src/tests/root.zig" },
    //     .imports = &[_]std.Build.Module.Import{
    //         .{ .name = "lexer", .module = lexer },
    //         .{ .name = "parser", .module = parser },
    //         .{ .name = "object", .module = object },
    //         .{ .name = "ast", .module = ast },
    //         .{ .name = "bytecode", .module = bytecode },
    //         .{ .name = "opcode", .module = opcode },
    //         .{ .name = "compiler", .module = compiler },
    //         .{ .name = "vm", .module = vm },
    //         .{ .name = "evaluator", .module = evaluator },
    //         .{ .name = "repl", .module = repl },
    //     },
    // });
    //
    exe.root_module.addImport("ast", ast);
    exe.root_module.addImport("token", token);
    exe.root_module.addImport("lexer", lexer);
    exe.root_module.addImport("object", object);
    exe.root_module.addImport("parser", parser);
    exe.root_module.addImport("environment", environment);
    exe.root_module.addImport("opcode", opcode);
    exe.root_module.addImport("bytecode", bytecode);
    exe.root_module.addImport("builtins", builtins);
    exe.root_module.addImport("compiler", compiler);
    exe.root_module.addImport("vm", vm);
    exe.root_module.addImport("eval_utils", eval_utils);
    exe.root_module.addImport("evaluator", evaluator);
    exe.root_module.addImport("repl", repl);

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
    unit_tests.root_module.addImport("repl", repl);
    // unit_tests.root_module.addImport("root", root);
    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
