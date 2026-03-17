const std = @import("std");
const Step = std.Build.Step;

const Config = struct {
    target: std.Build.ResolvedTarget,
    upstream: *std.Build.Dependency,
    glib: *Step.Compile,
    includes: []const std.Build.LazyPath,
    cflags: *std.ArrayList([]const u8),
};

pub fn build(
    b: *std.Build,
    config: Config,
) !void {
    const target = config.target;
    const glib = config.glib;
    const upstream = config.upstream;
    const sub_dir = "glib/tests";

    var tests_cflags = config.cflags.clone(b.allocator) catch @panic("OOM");
    defer tests_cflags.deinit(b.allocator);

    tests_cflags.appendSliceAssumeCapacity(&.{
        "-DG_LOG_DOMAIN=\"GLib\"",
        "-UG_DISABLE_ASSERT",
    });

    for (tests) |value| {
        const module = b.createModule(.{
            .target = target,
            .optimize = .Debug,
        });
        module.addCSourceFile(.{
            .file = upstream.path(b.fmt("{s}/{s}.c", .{ sub_dir, value })),
            .language = .c,
            .flags = tests_cflags.items,
        });
        for (config.includes) |path| module.addIncludePath(path);
        module.linkLibrary(glib);

        const test_exe = b.addExecutable(.{
            .name = value,
            .root_module = module,
        });

        const run_test = b.addRunArtifact(test_exe);
        run_test.expectExitCode(0);

        b.getInstallStep().dependOn(&run_test.step);
    }
}

const tests: []const []const u8 = &.{
    "array-test",
    "asyncqueue",
    "base64",
    // "bitlock",
    // "bookmarkfile",
    "bytes",
    // "cache",
    "charset",
    "checksum",
    // "completion",
    // "cond",
    "dataset",
    "dir",
    "environment",
    "error",
    // "fileutils",
    "guuid",
    "hash",
    "hmac",
    "hook",
    "hostutils",
    "io-channel-basic",
    // "io-channel",
    // "keyfile",
    "list",
    "logging",
    "mainloop",
    // "mappedfile",
    // "mapping",
    "markup",
    // "markup-parse",
    "markup-collect",
    "markup-escape",
    "markup-subparser",
    // "memchunk",
    "monotonic-time",
    // "mutex",
    "node",
    "once",
    "onceinit",
    "option-argv0",
    "overflow",
    "pathbuf",
    "pattern",
    // "private",
    "protocol",
    "queue",
    "rand",
    "rcbox",
    "rec-mutex",
    "refcount",
    "refstring",
    // "relation",
    "rwlock",
    "scannerapi",
    "search-utils",
    "shell",
    // "slice",
    "slist",
    "sort",
    "strfuncs",
    "strvbuilder",
    "test-printf",
    "thread",
    // "thread-deprecated",
    "thread-pool",
    "timeout",
    "timer",
    "tree",
    "types",
    "utf8-performance",
    "utf8-private",
    "utf8-validate",
    "utf8-misc",
    "utils-isolated",
    "utils-unisolated",
    // "unicode",
    // "unicode-encoding",
    // "unicode-normalize",
    "uri",
    "1bit-mutex",
};
