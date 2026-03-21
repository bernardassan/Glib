const std = @import("std");
const Step = std.Build.Step;

const platform = @import("../platform.zig");
const Platform = platform.Platform;

const Config = struct {
    target: std.Build.ResolvedTarget,
    upstream: *std.Build.Dependency,
    glib: *Step.Compile,
    includes: []const std.Build.LazyPath,
    cflags: *std.ArrayList(String),
};

const sub_dir = "glib/tests";

pub fn build(
    b: *std.Build,
    config: Config,
) !void {
    const extra_tests: std.StaticStringMap([]const String) = .initComptime(tests.extra);
    const failable_tests: std.StaticStringMap([]const Platform) = .initComptime(tests.failable);
    const failable_extra_tests: std.StaticStringMap(struct {
        []const Platform,
        []const String,
    }) = .initComptime(tests.failable_extra);

    var tests_cflags = config.cflags.clone(b.allocator) catch @panic("OOM");
    defer tests_cflags.deinit(b.allocator);

    tests_cflags.appendSliceAssumeCapacity(&.{
        "-DG_LOG_DOMAIN=\"GLib\"",
        "-UG_DISABLE_ASSERT",
    });

    buildTest(b, config, tests.simple, &tests_cflags);

    buildFailableTest(b, config, failable_tests, &tests_cflags);

    buildExtraTest(b, config, .{
        .names = extra_tests.keys(),
        .inputs = extra_tests.values(),
    }, &tests_cflags);

    buildFailableExtraTest(b, config, failable_extra_tests, &tests_cflags);
}

fn buildFailableTest(
    b: *std.Build,
    config: Config,
    failable_tests: std.StaticStringMap([]const Platform),
    tests_cflags: *const std.ArrayList(String),
) void {
    const rt = config.target.result;
    start: for (failable_tests.keys(), failable_tests.values()) |name, platforms| {
        skipPlatform(rt, platforms) catch |err| switch (err) {
            error.Skip => continue :start,
        };

        buildTest(b, config, &.{name}, tests_cflags);
    }
}

fn buildTest(
    b: *std.Build,
    config: Config,
    simple_test: []const String,
    tests_cflags: *const std.ArrayList(String),
) void {
    for (simple_test) |name| {
        const test_exe = compileTest(b, config, name, config.glib, tests_cflags);

        const run_test = b.addRunArtifact(test_exe);
        if (std.mem.eql(u8, name, "mapping")) run_test.setCwd(test_exe.getEmittedBinDirectory());
        run_test.expectExitCode(0);

        b.getInstallStep().dependOn(&run_test.step);
    }
}

fn buildFailableExtraTest(
    b: *std.Build,
    config: Config,
    failable_extra_tests: std.StaticStringMap(struct {
        []const Platform,
        []const String,
    }),
    tests_cflags: *const std.ArrayList(String),
) void {
    const rt = config.target.result;
    start: for (failable_extra_tests.keys(), failable_extra_tests.values()) |name, tuple| {
        const platforms, const inputs = tuple;
        skipPlatform(rt, platforms) catch |err| switch (err) {
            error.Skip => continue :start,
        };

        buildExtraTest(b, config, .{
            .names = &.{name},
            .inputs = &.{inputs},
        }, tests_cflags);
    }
}

fn buildExtraTest(
    b: *std.Build,
    config: Config,
    extra_tests: struct {
        names: []const String,
        inputs: []const []const String,
    },
    tests_cflags: *const std.ArrayList(String),
) void {
    for (extra_tests.names, extra_tests.inputs) |name, inputs| {
        const test_exe = compileTest(b, config, name, config.glib, tests_cflags);
        {}
        const container = b.addWriteFiles();
        const exe_file = container.addCopyFile(test_exe.getEmittedBin(), name);
        switch (inputs[0][inputs[0].len - 1]) {
            '/' => for (inputs) |input| {
                _ = container.addCopyDirectory(config.upstream.path(b.fmt("{s}/{s}", .{ sub_dir, input })), input, .{});
            },
            else => for (inputs) |input| {
                _ = container.addCopyFile(config.upstream.path(b.fmt("{s}/{s}", .{ sub_dir, input })), input);
            },
        }
        const run = Step.Run.create(b, b.fmt("run {s}", .{name}));
        run.addFileArg(exe_file);
        run.expectExitCode(0);
        b.getInstallStep().dependOn(&run.step);
    }
}

fn skipPlatform(rt: std.Target, platforms: []const Platform) !void {
    for (platforms) |skip_platform| {
        switch (rt.os.tag) {
            .macos => if (skip_platform == .darwin) return error.Skip,
            .freebsd => if (skip_platform == .freebsd) return error.Skip,
            .netbsd => if (skip_platform == .netbsd) return error.Skip,
            .openbsd => if (skip_platform == .openbsd) return error.Skip,
            .windows => if (skip_platform == .mingw) return error.Skip,
            .linux => (if (std.mem.eql(u8, @tagName(skip_platform), @tagName(rt.abi))) return error.Skip),
            else => {},
        }
        if (skip_platform == .unix) if (rt.os.tag != .windows) return error.Skip;
    }
}

fn compileTest(
    b: *std.Build,
    config: Config,
    name: String,
    glib: *Step.Compile,
    flags: *const std.ArrayList(String),
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
        .flags = flags.items,
    });
    for (config.includes) |path| module.addIncludePath(path);
    module.linkLibrary(glib);

    const test_exe = b.addExecutable(.{
        .name = name,
        .root_module = module,
    });
    return test_exe;
}

const String = []const u8;

const tests = struct {
    const simple: []const String = &.{
        "array-test",
        "asyncqueue",
        "atomic",
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
        "gvariant",
        "hash",
        "hmac",
        "hook",
        "hostutils",
        "io-channel-basic",
        "list",
        "logging",
        "macros",
        "mainloop",
        // "mapping",
        "markup",
        "markup-collect",
        "markup-escape",
        "markup-subparser",
        "max-version",
        "memchunk",
        "mem-overflow",
        "monotonic-time",
        "mutex",
        "node",
        "once",
        "onceinit",
        "option-argv0",
        "overflow",
        "pathbuf",
        "pattern",
        // can fail on windows
        "print",
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
        "sequence",
        "shell",
        "slice",
        "slist",
        "sort",
        "strfuncs",
        "string",
        "strvbuilder",
        "testing-nonfatal",
        "test-printf",
        "thread",
        "thread-deprecated",
        "thread-pool",
        "thread-pool-slow",
        "timeout",
        "timer",
        "tree",
        "types",
        "utf8-performance",
        "utf8-pointer",
        "utf8-private",
        "utf8-validate",
        "utf8-misc",
        "utils",
        "utils-isolated",
        "utils-unisolated",
        "uri",
        "1bit-mutex",
        "642026",
    };

    const failable: []const struct { String, []const Platform } = &.{
        // FIXME: can fail on musl https://wiki.musl-libc.org/roadmap#Open_future_goals
        .{ "collate", &.{.musl} },
        // FIXME: can fail on musl https://gitlab.gnome.org/GNOME/glib/-/issues/3182
        .{ "convert", &.{.musl} },
        // FIXME: can fail on musl and darwin
        // FIXME: darwin: https://gitlab.gnome.org/GNOME/glib/-/issues/1392
        // https://www.openwall.com/lists/musl/2023/08/10/3
        // FIXME: musl: https://gitlab.gnome.org/GNOME/glib/-/issues/3171
        .{ "date", &.{ .musl, .darwin } },
        // can fail on musl https://www.openwall.com/lists/musl/2023/08/10/3
        .{ "option-context", &.{.musl} },
    };

    const extra: []const struct {
        String,
        []const String,
    } = &.{
        .{ "bookmarkfile", &.{"bookmarks/"} },
        .{ "fileutils", &.{"4096-random-bytes"} },
        .{ "io-channel", &.{"iochannel-test-infile"} },
        .{ "keyfile", &.{ "keyfiletest.ini", "keyfile.c", "pages.ini" } },
        .{ "mappedfile", &.{ "empty", "4096-random-bytes" } },
        .{ "unicode", &.{ "casemap.txt", "casefold.txt" } },
        .{ "unicode-encoding", &.{"utf8.txt"} },
        .{ "unicode-normalize", &.{"NormalizationTest.txt"} },
    };

    const failable_extra: []const struct {
        String,
        struct { []const Platform, []const String },
    } = &.{
        .{ "markup-parse", .{ &.{.musl}, &.{"markups/"} } },
    };
};
