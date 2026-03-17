const std = @import("std");
const Step = std.Build.Step;

const platform = @import("../platform.zig");
const is = platform.is;
const tests = @import("tests.zig");

const c_flags: []const []const u8 = &.{
    "-DGLIB_COMPILATION",
    "-DG_LOG_DOMAIN=\"GLib\"",
};

const Config = struct {
    version: std.SemanticVersion,
    library_version: std.SemanticVersion,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    cflags: *std.ArrayList([]const u8),
    upstream: *std.Build.Dependency,
    glib_conf: *Step.ConfigHeader,
    glibconfig_conf: *Step.ConfigHeader,
    include_dir: []const u8,
    charsetalias_dir: []const u8,
};

const unix_headers: []const []const u8 = &.{
    "glib-unix.h",
};

// Linux, Windows, MacOs, Freebsd, Netbsd and Openbsd can spawn
const can_spawn = true;

// glib_conf.set('HAVE_SYSPROF", libsysprof_capture_dep.found())
pub fn build(b: *std.Build, config: Config) !void {
    const upstream = config.upstream;
    const glib_conf = config.glib_conf;
    const glibconfig_conf = config.glibconfig_conf;
    const target = config.target;
    const rt = target.result;
    const include_dir = config.include_dir;
    const sub_include_dir = b.fmt("{s}/glib", .{include_dir});
    _ = sub_include_dir; // autofix
    const unix_source: []const []const u8 = &.{
        "glib-unix.c",
        "giounix.c",
        if (rt.os.tag == .linux) "gjournal-private.c" else "",
        if (can_spawn) "gspawn-posix.c" else "gspawn-unsupported.c",
    };
    const windows_headers: []const []const u8 = &.{
        "gwin32.h",
    };
    _ = windows_headers; // autofix

    const gen_macros = b.addExecutable(.{
        .linkage = .static,
        .name = "gen-macros",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/gen-macros.zig"),
            .optimize = .Debug,
            .target = b.graph.host,
        }),
        .use_lld = false,
        .use_llvm = false,
    });

    const version = b.fmt("{f}", .{config.version});

    const version_macros_h = blk: {
        const run_gen_macros = b.addRunArtifact(gen_macros);
        run_gen_macros.addArgs(&.{
            version,
            "versions-macros",
        });
        run_gen_macros.addFileArg(upstream.path("glib/gversionmacros.h.in"));
        const version_macros = run_gen_macros.addOutputFileArg("glib/gversionmacros.h");
        break :blk version_macros;
    };

    const visibility_h = blk: {
        const run_gen_macros = b.addRunArtifact(gen_macros);
        run_gen_macros.addArgs(&.{
            version,
            "visibility-macros",
            "GLIB",
        });
        const visibility_macros = run_gen_macros.addOutputFileArg("glib/glib-visibility.h");
        break :blk visibility_macros;
    };

    const charset = buildCharset(b, config);
    var include_paths: std.ArrayList(std.Build.LazyPath) = try .initCapacity(b.allocator, 6);
    include_paths.appendSliceAssumeCapacity(&.{
        glib_conf.getOutputDir(),
        glibconfig_conf.getOutputDir(),
        version_macros_h.dirname().dirname(),
        visibility_h.dirname().dirname(),
        upstream.path("."),
        upstream.path("glib"),
    });

    const glib_mod = b.createModule(.{
        .link_libc = true,
        .optimize = config.optimize,
        .target = target,
    });

    for (include_paths.items) |path| glib_mod.addIncludePath(path);
    config.cflags.appendSliceAssumeCapacity(c_flags);
    glib_mod.addCSourceFiles(.{
        .root = upstream.path("glib"),
        .files = glib_sources,
        .language = .c,
        .flags = config.cflags.items,
    });
    if (!rt.isMinGW()) glib_mod.addCSourceFiles(.{
        .root = upstream.path("glib"),
        .files = unix_source,
        .language = .c,
        .flags = config.cflags.items,
    });
    glib_mod.linkLibrary(charset);

    const glib = b.addLibrary(.{
        .name = "glib-2.0",
        .root_module = glib_mod,
        .linkage = config.linkage,
        .max_rss = 160 * 1024 * 1024,
        .version = config.library_version,
    });

    try tests.build(b, .{
        .glib = glib,
        .upstream = upstream,
        .target = target,
        .includes = include_paths.items,
        .cflags = config.cflags,
    });
    // b.installArtifact(glib);
    _ = unix_headers; // autofix
    _ = headers; // autofix
}

pub fn buildCharset(b: *std.Build, config: Config) *Step.Compile {
    const charset_module = b.createModule(.{
        .optimize = config.optimize,
        .pic = true,
        .target = config.target,
        .link_libc = true,
    });
    const charset_dir = config.upstream.path("glib/libcharset");

    var charset_cflags = config.cflags.clone(b.allocator) catch @panic("OOM");
    defer charset_cflags.deinit(b.allocator);

    charset_cflags.appendSliceAssumeCapacity(&.{
        "-Wno-sign-conversion",
        b.fmt("-DGLIB_CHARSETALIAS_DIR=\"{s}\"", .{config.charsetalias_dir}),
    });
    charset_module.addCSourceFiles(.{
        .root = charset_dir,
        .language = .c,
        .files = &.{"localcharset.c"},
        .flags = charset_cflags.items,
    });
    charset_module.addIncludePath(charset_dir);
    charset_module.addConfigHeader(config.glib_conf);

    const charset = b.addLibrary(.{
        .name = "charset",
        .root_module = charset_module,
        .linkage = .static,
    });
    return charset;
}

const headers: []const []const u8 = &.{
    "glib.h",
    "glib-object.h",
};

const sub_headers: []const []const u8 = &.{
    "glib-autocleanups.h",
    "glib-typeof.h",
    "galloca.h",
    "garray.h",
    "gasyncqueue.h",
    "gatomic.h",
    "gbacktrace.h",
    "gbase64.h",
    "gbitlock.h",
    "gbookmarkfile.h",
    "gbytes.h",
    "gcharset.h",
    "gchecksum.h",
    "gconvert.h",
    "gdataset.h",
    "gdate.h",
    "gdatetime.h",
    "gdir.h",
    "genviron.h",
    "gerror.h",
    "gfileutils.h",
    "ggettext.h",
    "ghash.h",
    "ghmac.h",
    "ghook.h",
    "ghostutils.h",
    "gi18n.h",
    "gi18n-lib.h",
    "giochannel.h",
    "gkeyfile.h",
    "glist.h",
    "gmacros.h",
    "gmain.h",
    "gmappedfile.h",
    "gmarkup.h",
    "gmem.h",
    "gmessages.h",
    "gnode.h",
    "goption.h",
    "gpathbuf.h",
    "gpattern.h",
    "gpoll.h",
    "gprimes.h",
    "gqsort.h",
    "gquark.h",
    "gqueue.h",
    "grand.h",
    "grcbox.h",
    "grefcount.h",
    "grefstring.h",
    "gregex.h",
    "gscanner.h",
    "gsequence.h",
    "gshell.h",
    "gslice.h",
    "gslist.h",
    "gspawn.h",
    "gstdio.h",
    "gstrfuncs.h",
    "gstrvbuilder.h",
    "gtestutils.h",
    "gstring.h",
    "gstringchunk.h",
    "gthread.h",
    "gthreadpool.h",
    "gtimer.h",
    "gtimezone.h",
    "gtrashstack.h",
    "gtree.h",
    "gtypes.h",
    "guuid.h",
    "gunicode.h",
    "guri.h",
    "gutils.h",
    "gvarianttype.h",
    "gvariant.h",
    "gversion.h",
    "gprintf.h",
};

const glib_sources: []const []const u8 = &.{
    "garcbox.c",
    "garray.c",
    "gasyncqueue.c",
    "gatomic.c",
    "gbacktrace.c",
    "gbase64.c",
    "gbitlock.c",
    "gbookmarkfile.c",
    "gbytes.c",
    "gcharset.c",
    "gchecksum.c",
    "gconvert.c",
    "gdataset.c",
    "gdate.c",
    "gdatetime.c",
    "gdatetime-private.c",
    "gdir.c",
    "genviron.c",
    "gerror.c",
    "gfileutils.c",
    "ggettext.c",
    "ghash.c",
    "ghmac.c",
    "ghook.c",
    "ghostutils.c",
    "giochannel.c",
    "gkeyfile.c",
    "glib-init.c",
    "glib-private.c",
    "glist.c",
    "gmain.c",
    "gmappedfile.c",
    "gmarkup.c",
    "gmem.c",
    "gmessages.c",
    "gnode.c",
    "goption.c",
    "gpathbuf.c",
    "gpattern.c",
    "gpoll.c",
    "gprimes.c",
    "gqsort.c",
    "gquark.c",
    "gqueue.c",
    "grand.c",
    "grcbox.c",
    "grefcount.c",
    "grefstring.c",
    "gregex.c",
    "gscanner.c",
    "gsequence.c",
    "gshell.c",
    "gslice.c",
    "gslist.c",
    "gspawn.c",
    "gstdio.c",
    "gstrfuncs.c",
    "gstring.c",
    "gstringchunk.c",
    "gstrvbuilder.c",
    "gtestutils.c",
    "gthread.c",
    "gthreadpool.c",
    "gtimer.c",
    "gtimezone.c",
    "gtrace.c",
    "gtranslit.c",
    "gtrashstack.c",
    "gtree.c",
    "guniprop.c",
    "gutf8.c",
    "gunibreak.c",
    "gunicollate.c",
    "gunidecomp.c",
    "guri.c",
    "gutils.c",
    "guuid.c",
    "gvariant.c",
    "gvariant-core.c",
    "gvariant-parser.c",
    "gvariant-serialiser.c",
    "gvarianttypeinfo.c",
    "gvarianttype.c",
    "gversion.c",
    "gwakeup.c",
    "gprint.c",
    "gprintf.c",
};
