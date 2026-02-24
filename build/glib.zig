const std = @import("std");
const Step = std.Build.Step;

const platform = @import("platform.zig");
const is = platform.is;

const c_flags: []const []const u8 = &.{
    "-DGLIB_COMPILATION",
    "-DG_LOG_DOMAIN=\"GLib\"",
};

const Config = struct {
    library_version: std.SemanticVersion,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    cflags: *std.ArrayList([]const u8),
    upstream: *std.Build.Dependency,
    glib_conf: *Step.ConfigHeader,
    glibconfig_conf: *Step.ConfigHeader,
    version_h: *Step.ConfigHeader,
};

// Linux, Windows, MacOs, Freebsd, Netbsd and Openbsd can spawn
const can_spawn = true;

// glib_conf.set('HAVE_SYSPROF", libsysprof_capture_dep.found())
pub fn build(b: *std.Build, config: Config) !void {
    const upstream = config.upstream;
    const glib_conf = config.glib_conf;
    const glibconfig_conf = config.glibconfig_conf;
    const version_h = config.version_h;
    const rt = config.target.result;

    const unix_headers: []const []const u8 = &.{
        "glib-unix.h",
    };

    const unix_source: []const []const u8 = &.{
        "glib-unix.c",
        "giounix.c",
        if (rt.os.tag == .linux) "gjournal-private.c" else "",
        if (can_spawn) "gspawn-posix.c" else "gspawn-unsupported.c",
    };
    _ = unix_source; // autofix
    const windows_headers: []const []const u8 = &.{
        "gwin32.h",
    };
    _ = windows_headers; // autofix

    const glib_mod = b.createModule(.{
        .link_libc = true,
        .optimize = config.optimize,
        .target = config.target,
    });
    glib_mod.addIncludePath(b.path("build"));
    glib_mod.addIncludePath(upstream.path("."));
    glib_mod.addIncludePath(upstream.path("glib"));
    glib_mod.addIncludePath(upstream.path("gobject"));
    glib_mod.addIncludePath(upstream.path("gmodule"));
    glib_mod.addIncludePath(upstream.path("gio"));
    glib_mod.addIncludePath(upstream.path("girepository"));
    glib_mod.addConfigHeader(glib_conf);
    glib_mod.addConfigHeader(glibconfig_conf);
    glib_mod.addConfigHeader(version_h);

    config.cflags.appendSliceAssumeCapacity(c_flags);
    glib_mod.addCSourceFiles(.{
        .root = upstream.path("glib"),
        .files = glib_sources,
        .language = .c,
        .flags = config.cflags.items,
    });

    const glib = b.addLibrary(.{
        .name = "glib-2.0",
        .root_module = glib_mod,
        .linkage = config.linkage,
        .max_rss = 1024 * 1024,
        .version = config.library_version,
    });

    glib.step.dependOn(&version_h.step);
    glib.step.dependOn(&glib_conf.step);

    b.installArtifact(glib);
    _ = unix_headers; // autofix
    _ = headers; // autofix
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
