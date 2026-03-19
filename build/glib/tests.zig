const std = @import("std");
const Step = std.Build.Step;

const Config = struct {
    target: std.Build.ResolvedTarget,
    upstream: *std.Build.Dependency,
    glib: *Step.Compile,
    includes: []const std.Build.LazyPath,
    cflags: *std.ArrayList([]const u8),
};

const sub_dir = "glib/tests";
pub fn build(
    b: *std.Build,
    config: Config,
) !void {
    const extra_test: std.StaticStringMap([]const []const u8) = .initComptime(extra_tests);
    const upstream = config.upstream;

    var tests_cflags = config.cflags.clone(b.allocator) catch @panic("OOM");
    defer tests_cflags.deinit(b.allocator);

    tests_cflags.appendSliceAssumeCapacity(&.{
        "-DG_LOG_DOMAIN=\"GLib\"",
        "-UG_DISABLE_ASSERT",
    });

    for (tests) |name| {
        const test_exe = buildTest(b, config, name, config.glib, tests_cflags.items);

        const run_test = b.addRunArtifact(test_exe);
        if (std.mem.eql(u8, name, "mapping")) run_test.setCwd(test_exe.getEmittedBinDirectory());
        run_test.expectExitCode(0);

        b.getInstallStep().dependOn(&run_test.step);
    }

    for (extra_test.keys(), extra_test.values()) |name, inputs| {
        const test_exe = buildTest(b, config, name, config.glib, tests_cflags.items);
        {}
        const container = b.addWriteFiles();
        const exe_file = container.addCopyFile(test_exe.getEmittedBin(), name);
        switch (inputs[0][inputs[0].len - 1]) {
            '/' => for (inputs) |input| {
                _ = container.addCopyDirectory(upstream.path(b.fmt("{s}/{s}", .{ sub_dir, input })), input, .{});
            },
            else => for (inputs) |input| {
                _ = container.addCopyFile(upstream.path(b.fmt("{s}/{s}", .{ sub_dir, input })), input);
            },
        }
        const run = Step.Run.create(b, b.fmt("run {s}", .{name}));
        run.addFileArg(exe_file);
        run.expectExitCode(0);
        b.getInstallStep().dependOn(&run.step);
    }
}

fn buildTest(
    b: *std.Build,
    config: Config,
    name: []const u8,
    glib: *Step.Compile,
    flags: []const []const u8,
) *Step.Compile {
    const module = b.createModule(.{
        .target = config.target,
        .optimize = .Debug,
        .link_libc = true,
        .sanitize_c = .off,
    });
    module.addCSourceFile(.{
        .file = config.upstream.path(b.fmt("{s}/{s}.c", .{ sub_dir, name })),
        .language = .c,
        .flags = flags,
    });
    for (config.includes) |path| module.addIncludePath(path);
    module.linkLibrary(glib);

    const test_exe = b.addExecutable(.{
        .name = name,
        .root_module = module,
    });
    return test_exe;
}

const tests: []const []const u8 = &.{
    "array-test",
    "asyncqueue",
    "base64",
    "bitlock",
    "bytes",
    "cache",
    "charset",
    "checksum",
    "completion",
    "cond",
    "dataset",
    "dir",
    "environment",
    "error",
    "guuid",
    "hash",
    "hmac",
    "hook",
    "hostutils",
    "io-channel-basic",
    "list",
    "logging",
    "mainloop",
    // "mapping",
    "markup",
    "markup-collect",
    "markup-escape",
    "markup-subparser",
    "memchunk",
    "monotonic-time",
    "mutex",
    "node",
    "once",
    "onceinit",
    "option-argv0",
    "overflow",
    "pathbuf",
    "pattern",
    "private",
    "protocol",
    "queue",
    "rand",
    "rcbox",
    "rec-mutex",
    "refcount",
    "refstring",
    "relation",
    "rwlock",
    "scannerapi",
    "search-utils",
    "shell",
    "slice",
    "slist",
    "sort",
    "strfuncs",
    "strvbuilder",
    "test-printf",
    "thread",
    "thread-deprecated",
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
    "uri",
    "1bit-mutex",
};

const extra_tests: []const struct { []const u8, []const []const u8 } = &.{
    .{ "bookmarkfile", &.{"bookmarks/"} },
    .{ "fileutils", &.{"4096-random-bytes"} },
    .{ "io-channel", &.{"iochannel-test-infile"} },
    .{ "keyfile", &.{ "keyfiletest.ini", "keyfile.c", "pages.ini" } },
    .{ "mappedfile", &.{ "empty", "4096-random-bytes" } },
    .{ "markup-parse", &.{"markups/"} },
    .{ "unicode", &.{ "casemap.txt", "casefold.txt" } },
    .{ "unicode-encoding", &.{"utf8.txt"} },
    .{ "unicode-normalize", &.{"NormalizationTest.txt"} },
};
