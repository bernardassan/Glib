const std = @import("std");
const Step = std.Build.Step;

const platform = @import("../platform.zig");
const Platform = platform.Platform;
const root = @import("root.zig");

const sub_dir = "glib/tests";

const Config = struct {
    build_root: String,
    target: std.Build.ResolvedTarget,
    upstream: *std.Build.Dependency,
    deps: *std.EnumArray(root.Dependencies, root.Library),
    includes: []const std.Build.LazyPath,
    cflags: *std.ArrayList(String),
};

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
    const source_tests: std.StaticStringMap(tests.SourceInfo) = .initComptime(tests.sources);

    var tests_cflags = config.cflags;
    tests_cflags.appendSliceAssumeCapacity(&.{
        "-DG_LOG_DOMAIN=\"GLib\"",
        "-UG_DISABLE_ASSERT",
    });
    defer {
        _ = tests_cflags.pop();
        _ = tests_cflags.pop();
    }

    buildTest(b, config, tests.simple, tests_cflags);

    buildFailableTest(b, config, failable_tests, tests_cflags);

    buildExtraTest(b, config, .{
        .names = extra_tests.keys(),
        .inputs = extra_tests.values(),
    }, tests_cflags);

    buildFailableExtraTest(b, config, failable_extra_tests, tests_cflags);

    buildSourcesTest(b, config, source_tests, tests_cflags);
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
        const test_exe = compileTest(b, config, name, tests_cflags);

        const run_test = createRun(b, name);
        if (!std.mem.eql(u8, name, "mapping")) {
            run_test.addArtifactArg(test_exe);
        } else {
            // TODO: maybe precompute the cwd so its done once for the whole
            // build instead of once here and again in `buildExtraTest`
            // TODO: The mapping test requres an absolute directory to itself
            // to be able to respawn its child after it has changed into the tmp
            // directory The below approach feels hacky and brittle find a
            // better way to get an absolute directory to the test `mapping`
            // binary
            run_test.addPrefixedFileArg(config.build_root, test_exe.getEmittedBin());
        }
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

fn buildSourcesTest(
    b: *std.Build,
    config: Config,
    source_tests: std.StaticStringMap(tests.SourceInfo),
    tests_cflags: *std.ArrayList(String),
) void {
    const rt = config.target.result;
    start: for (source_tests.keys(), source_tests.values()) |name, source| {
        if (source.skip) |skip| skipPlatform(rt, skip) catch |err| switch (err) {
            error.Skip => continue :start,
        };
        const test_exe_file = compileSourceTest(b, config, name, source, tests_cflags);
        const run_test = createRun(b, name);
        run_test.addPrefixedFileArg(config.build_root, test_exe_file);
        run_test.expectExitCode(0);
        b.getInstallStep().dependOn(&run_test.step);
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
        const test_exe = compileTest(b, config, name, tests_cflags);
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

        const run_test = createRun(b, name);
        if (!std.mem.eql(u8, name, "gdatetime")) {
            run_test.addFileArg(exe_file);
        } else {
            // gdatetime requires an absolute path to location of timezone input
            // or exe with timezone directory nested in it. Don't use the
            // `env G_TEST_SRCDIR=config.upstream.path(sub_dir) ./exe_file`
            // approach as that is too platform specific
            run_test.addPrefixedFileArg(config.build_root, exe_file);
        }
        run_test.expectExitCode(0);
        b.getInstallStep().dependOn(&run_test.step);
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

fn compileSourceTest(
    b: *std.Build,
    config: Config,
    name: String,
    source: tests.SourceInfo,
    flags: *std.ArrayList(String),
) std.Build.LazyPath {
    const module = b.createModule(.{
        .target = config.target,
        .optimize = .Debug,
        .link_libc = true,
    });

    if (source.c_args) |c_args| flags.appendAssumeCapacity(c_args);
    defer if (source.c_args) |_| {
        _ = flags.pop();
    };
    module.addCSourceFile(.{
        .file = config.upstream.path(b.fmt("{s}/{s}", .{ sub_dir, source.source })),
        .language = .c,
        .flags = flags.items,
    });
    module.sanitize_c = source.sanitize;
    for (config.includes) |path| module.addIncludePath(path);
    // TODO: seems like a compiler error. Putting if and for doesn't execute else branch
    if (source.deps) |deps| {
        for (deps) |dep| {
            switch (config.deps.get(dep)) {
                .local => |lib| module.linkLibrary(lib),
                .system => |sys_lib| module.linkSystemLibrary(sys_lib, .{}),
            }
        }
    } else module.linkLibrary(config.deps.get(.glib).local);

    const test_exe = b.addExecutable(.{
        .name = name,
        .root_module = module,
    });

    if (source.sub_programs) |sub_programs| {
        const container = b.addWriteFiles();
        for (sub_programs) |program| {
            const sub_test_exe = compileTest(b, config, program, flags);

            _ = container.addCopyFile(sub_test_exe.getEmittedBin(), program);
        }

        if (source.input_file) |input_file| _ = container.addCopyFile(
            config.upstream.path(b.fmt("{s}/{s}", .{ sub_dir, input_file })),
            input_file,
        );

        const test_exe_file = container.addCopyFile(test_exe.getEmittedBin(), name);
        return test_exe_file;
    }

    return test_exe.getEmittedBin();
}

fn compileTest(
    b: *std.Build,
    config: Config,
    name: String,
    flags: *const std.ArrayList(String),
) *Step.Compile {
    const module = b.createModule(.{
        .target = config.target,
        .optimize = .Debug,
        .link_libc = true,
    });

    module.addCSourceFile(.{
        .file = config.upstream.path(b.fmt("{s}/{s}.c", .{ sub_dir, name })),
        .language = .c,
        .flags = flags.items,
    });
    for (config.includes) |path| module.addIncludePath(path);
    const glib = config.deps.get(.glib);
    module.linkLibrary(glib.local);

    // TODO: this is only required for `spawn-path-search` test so having it
    // here feels inaffecient find a way around it
    const name_ = blk: {
        _, const after = std.mem.cut(u8, name, "/") orelse break :blk name;
        break :blk after;
    };

    const test_exe = b.addExecutable(.{
        .name = name_,
        .root_module = module,
    });
    return test_exe;
}

fn createRun(b: *std.Build, name: []const u8) *Step.Run {
    const run_test = Step.Run.create(b, b.fmt("run {s}", .{name}));
    return run_test;
}

const String = []const u8;

const tests = struct {
    const simple: []const String = &.{
        "array-test",
        "asyncqueue",
        "atomic",
        "base64",
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
        "mapping",
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
        "spawn-test",
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
        // TODO: test to make sure it can indeed fail on windows
        // can fail on windows
        .{ "print", &.{.mingw} },
    };

    const extra: []const struct {
        String,
        []const String,
    } = &.{
        .{ "autoptr", &.{"keyfiletest.ini"} },
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
        // TODO: test to see if it actually fails on mingw
        .{ "gdatetime", .{ &.{ .musl, .mingw }, &.{"time-zones/"} } },
    };

    const SourceInfo = struct {
        source: String,
        c_args: ?String,
        sanitize: ?std.zig.SanitizeC,
        deps: ?[]const root.Dependencies,
        sub_programs: ?[]const String,
        input_file: ?String,
        skip: ?[]const Platform,
    };
    const sources: []const struct { String, SourceInfo } = &.{
        .{
            "gwakeup",
            .{
                .source = "gwakeuptest.c",
                .c_args = null,
                .sanitize = null,
                .deps = null,
                .sub_programs = null,
                .input_file = null,
                .skip = null,
            },
        },
        .{
            "gwakeup-fallback",
            .{
                .source = "gwakeuptest.c",
                .c_args = "-DTEST_EVENTFD_FALLBACK",
                .sanitize = null,
                .deps = null,
                .sub_programs = null,
                .input_file = null,
                // these platforms don't have `eventfd`
                .skip = &.{ .darwin, .openbsd, .mingw },
            },
        },
        .{
            "regex",
            .{
                .source = "regex.c",
                .sanitize = null,
                // TODO: only add in static build and check if any issues without it
                // .define = "PCRE2_STATIC",
                .c_args = null,
                .deps = &.{ .glib, .pcre2 },
                .sub_programs = null,
                .input_file = null,
                .skip = null,
            },
        },
        .{
            "overflow-fallback",
            .{
                .source = "overflow.c",
                .sanitize = null,
                .c_args = "-D_GLIB_TEST_OVERFLOW_FALLBACK",
                .deps = null,
                .sub_programs = null,
                .input_file = null,
                .skip = null,
            },
        },
        .{
            "refcount-macro",
            .{
                .source = "refcount.c",
                .sanitize = null,
                .c_args = "-DG_DISABLE_CHECKS",
                .deps = null,
                .sub_programs = null,
                .input_file = null,
                .skip = null,
            },
        },
        .{
            "1bit-emufutex",
            .{
                .source = "1bit-mutex.c",
                .sanitize = null,
                .c_args = "-DTEST_EMULATED_FUTEX",
                .deps = null,
                .sub_programs = null,
                .input_file = null,
                .skip = null,
            },
        },
        .{
            "642026-ec",
            .{
                .source = "642026.c",
                .sanitize = null,
                .c_args = "-DG_ERRORCHECK_MUTEXES",
                .deps = null,
                .sub_programs = null,
                .input_file = null,
                .skip = null,
            },
        },
        .{
            "bitlock",
            .{
                .source = "bitlock.c",
                .sanitize = .off,
                .c_args = null,
                .deps = null,
                .sub_programs = null,
                .input_file = null,
                .skip = null,
            },
        },
        .{
            "spawn-multithreaded",
            .{
                .source = "spawn-multithreaded.c",
                .sanitize = null,
                .c_args = null,
                .deps = null,
                .sub_programs = &.{
                    "test-spawn-echo",
                    "test-spawn-sleep",
                },
                .input_file = null,
                .skip = &.{.mingw},
            },
        },
        .{
            "spawn-path-search",
            .{
                .source = "spawn-path-search.c",
                .sanitize = null,
                .c_args = null,
                .deps = null,
                .input_file = null,
                .sub_programs = &.{
                    "spawn-path-search-helper",
                    "spawn-test-helper",
                    "path-test-subdir/spawn-test-helper",
                },
                .skip = null,
            },
        },
        .{
            "spawn-singlethread",
            .{
                .source = "spawn-singlethread.c",
                .sanitize = null,
                .c_args = null,
                .deps = null,
                .sub_programs = &.{
                    "test-spawn-echo",
                },
                .input_file = "echo-script",
                .skip = &.{.mingw},
            },
        },
        .{
            "spawn-singlethread-win",
            .{
                .source = "spawn-singlethread.c",
                .sanitize = null,
                .c_args = null,
                .deps = &.{.ws2_32},
                .sub_programs = &.{
                    "test-spawn-echo",
                },
                .input_file = "echo-script.bat",
                .skip = &.{.unix},
            },
        },
        .{
            "spawn-test-win",
            .{
                .source = "spawn-test.c",
                .sanitize = null,
                .c_args = null,
                .deps = null,
                .sub_programs = &.{
                    "spawn-test-win32-gui",
                },
                .input_file = null,
                .skip = &.{.unix},
            },
        },
        .{
            "testing",
            .{
                .source = "testing.c",
                .sanitize = null,
                .c_args = "",
                .deps = null,
                .sub_programs = &.{
                    "testing-helper",
                },
                .input_file = null,
                .skip = null,
            },
        },
        .{
            "gpoll",
            .{
                .source = "gpoll.c",
                .c_args = null,
                .sanitize = null,
                .deps = &.{ .glib, .ws2_32 },
                .sub_programs = null,
                .input_file = null,
                .skip = &.{.unix},
            },
        },
        .{
            "win32",
            .{
                .source = "win32.c",
                .c_args = null,
                .sanitize = null,
                .deps = &.{ .glib, .windowscodecs },
                .sub_programs = null,
                .input_file = null,
                .skip = &.{.unix},
            },
        },
        .{
            "win32-private",
            .{
                .source = "win32-private.c",
                .c_args = null,
                .sanitize = null,
                .deps = &.{ .glib, .ws2_32 },
                .sub_programs = null,
                .input_file = null,
                .skip = &.{.unix},
            },
        },
        .{
            "include",
            .{
                .source = "include.c",
                .c_args = null,
                .sanitize = null,
                .deps = null,
                .sub_programs = null,
                .input_file = null,
                .skip = &.{.mingw},
            },
        },
        .{
            "unix",
            .{
                .source = "unix.c",
                .c_args = null,
                .sanitize = null,
                .deps = null,
                .sub_programs = null,
                .input_file = null,
                .skip = &.{.mingw},
            },
        },
        // FIXME: mabye implement `gutils-user-database` and `constructor` which
        // test dynamic symobl loading https://github.com/GNOME/glib/blob/f983e388431c59e31198874e87b92163423b7353/glib/tests/meson.build#L266
        // https://github.com/GNOME/glib/blob/f983e388431c59e31198874e87b92163423b7353/glib/tests/meson.build#L374
        // FIXME: Skip python tests for now `assert-msg-test.py` and
        // `messages-low-memory.py`
    };
};
