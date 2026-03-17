const std = @import("std");
const Step = std.Build.Step;

const tests: []const []const u8 = &.{
    "array-test",
};

const Config = struct {
    target: std.Build.ResolvedTarget,
    upstream: *std.Build.Dependency,
    glib: *Step.Compile,
    includes: []const std.Build.LazyPath,
};

pub fn build(
    b: *std.Build,
    config: Config,
) !void {
    const target = config.target;
    const glib = config.glib;
    const upstream = config.upstream;

    const sub_dir = "glib/tests";
    for (tests) |value| {
        const module = b.createModule(.{
            .target = target,
            .optimize = .Debug,
        });
        module.addCSourceFile(.{
            .file = upstream.path(b.fmt("{s}/{s}.c", .{ sub_dir, value })),
            .language = .c,
        });
        for (config.includes) |path| module.addIncludePath(path);
        module.linkLibrary(glib);
        const test_exe = b.addExecutable(.{
            .name = value,
            .root_module = module,
        });
        const run_test = b.addRunArtifact(test_exe);
        run_test.expectStdErrEqual("");
        run_test.expectStdOutEqual("");
        run_test.expectExitCode(0);
        b.getInstallStep().dependOn(&run_test.step);
    }
}
