const std = @import("std");
const build_zon = @import("build.zig.zon");
const builtin = @import("builtin");
const mem = std.mem;

const Step = std.Build.Step;

const Buildtype = enum { debugoptimized };
const WarnLevel = enum { @"1", @"2", @"3" };
const Cstd = enum { gnu99, c99, c11, c17, c23 }; // TODO: make c11 default and try higer versions to see if they compile
const Feature = enum { enabled, disabled, auto };
const MonitorBackend = enum { auto, inotify, kqueue, @"libinotify-kqueue", win32 };

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const rt = target.result;

    const upstream = b.dependency("glib2", .{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "linkage mode for library") orelse .static;

    const gio_module_dir = b.option([]const u8, "gio_module_dir", "load gio modules from this directory (default to '${libdir}/gio/modules' if unset)");
    const selinux = b.option(Feature, "selinux", "build with selinux support") orelse .auto;
    _ = selinux; // autofix

    const xattr = b.option(bool, "xattr", "build with xattr support") orelse true;
    _ = xattr; // autofix

    const libmount = b.option(Feature, "libmount", "build with libmount support") orelse .auto;
    _ = libmount; // autofix
    const man_pages = b.option(Feature, "man-pages", "generate man pages (requires rst2man)") orelse .auto;
    const dtrace = b.option(Feature, "dtrace", "include tracing support for dtrace") orelse .auto;
    _ = dtrace; // autofix
    const systemtap = b.option(Feature, "systemtap", "include tracing support for systemtap") orelse .auto;
    _ = systemtap; // autofix

    const tapset_install_dir = b.option([]const u8, "tapset_install_dir", "path where systemtap tapsets are installed") orelse "";
    const sysprof = b.option(Feature, "sysprof", "include tracing support for sysprof") orelse .auto;

    const documentation = b.option(bool, "documentation", "Build API reference and tools documentation") orelse false;
    const bsymbolic_functions = b.option(bool, "bsymbolic_functions", "link with -Bsymbolic-functions if supported") orelse true;
    const force_posix_threads = b.option(bool, "force_posix_threads", "Also use posix threads in case the platform defaults to another implementation (on Windows for example)") orelse false;
    const enable_tests = b.option(bool, "tests", "build tests") orelse true;
    _ = enable_tests; // autofix

    const installed_tests = b.option(bool, "installed_tests", "enable installed tests") orelse false;

    const nls = b.option(Feature, "nls", "Enable native language support (translations)") orelse .auto;
    _ = nls; // autofix

    const oss_fuzz = b.option(Feature, "oss_fuzz", "Indicate oss-fuzz build environment") orelse .disabled;
    _ = oss_fuzz; // autofix
    _ = force_posix_threads; // autofix
    _ = documentation; // autofix
    _ = sysprof; // autofix
    _ = tapset_install_dir; // autofix
    _ = man_pages; // autofix
    const glib_debug = b.option(Feature, "glib_debug", "Enable GLib debug infrastructure (distros typically want this disabled in production; see docs/macros.md)") orelse .enabled;
    _ = glib_debug; // autofix

    const glib_assert = b.option(bool, "glib_assert", "Enable GLib assertion (see docs/macros.md)") orelse true;

    const glib_checks = b.option(bool, "glib_checks", "Enable GLib checks such as API guards (see docs/macros.md)") orelse true;

    const libelf = b.option(Feature, "libelf", "Enable support for listing and extracting from ELF resource files with gresource tool") orelse .auto;
    _ = libelf; // autofix
    const gir_dir_prefix = b.option([]const u8, "gir_dir_prefix", "Intermediate prefix for gir installation under ${prefix}");
    _ = gir_dir_prefix; // autofix
    const introspection = b.option(Feature, "introspection", "Enable generating introspection data (requires gobject-introspection)") orelse
        .auto;
    const file_monitor_backend = b.option(MonitorBackend, "file_monitor_backend", "The name of the system API to use as a GFileMonitor backend") orelse .auto;
    _ = file_monitor_backend; // autofix
    _ = introspection; // autofix

    const default_options = b.addOptions();
    default_options.addOption(Buildtype, "buildtype", .debugoptimized);
    default_options.addOption(WarnLevel, "warnlevel", .@"3");
    default_options.addOption(Cstd, "c_std", .c11);

    const glib_prefix = b.install_path;
    const glib_bindir = b.exe_dir;
    _ = glib_bindir; // autofix
    const glib_libdir = b.lib_dir;
    const includedir = b.h_dir;
    const libexecdir = b.pathJoin(&.{ glib_libdir, "libexec" });
    const datadir = b.pathJoin(&.{ glib_prefix, "share" });
    const localedir = b.pathJoin(&.{ glib_prefix, "share/locale" });
    const localstatedir = b.pathJoin(&.{ glib_prefix, "state" });
    const glib_libexecdir = b.pathJoin(&.{ glib_prefix, libexecdir });
    const glib_datadir = b.pathJoin(&.{ glib_prefix, datadir });
    const glib_localedir = b.pathJoin(&.{ glib_prefix, localedir });
    _ = glib_localedir; // autofix
    const glib_pkgdatadir = b.pathJoin(&.{ glib_datadir, "glib-2.0" });
    _ = glib_pkgdatadir; // autofix
    const glib_includedir = b.pathJoin(&.{ glib_prefix, includedir, "glib-2.0" });
    _ = glib_includedir; // autofix
    const glib_giomodulesdir = if (gio_module_dir) |gio_modules_dir| b.pathJoin(&.{ glib_prefix, gio_modules_dir }) else b.pathJoin(&.{ glib_libdir, "gio", "modules" });
    _ = glib_giomodulesdir; // autofix

    const glib_pkgconfigreldir = b.pathJoin(&.{ glib_libdir, "pkgconfig" });
    _ = glib_pkgconfigreldir; // autofix
    const glib_localstatedir = b.pathJoin(&.{ glib_prefix, localstatedir });
    _ = glib_localstatedir; // autofix

    const installed_tests_metadir = b.pathJoin(&.{ glib_datadir, "installed-tests", @tagName(build_zon.name) });
    _ = installed_tests_metadir; // autofix
    const installed_tests_execdir = b.pathJoin(&.{ glib_libexecdir, "installed-tests", @tagName(build_zon.name) });
    _ = installed_tests_execdir; // autofix
    const installed_tests_enabled = installed_tests;
    _ = installed_tests_enabled; // autofix
    const installed_tests_template = "tests/template.test.in";
    _ = installed_tests_template; // autofix
    const installed_tests_template_tap = "tests/template-tap.test.in";
    _ = installed_tests_template_tap; // autofix

    var test_env: std.process.Environ.Map = .init(b.allocator);
    defer test_env.deinit();

    try test_env.put("G_DEBUG", "gc-friendly");
    try test_env.put("G_ENABLE_DIAGNOSTIC", "1");
    try test_env.put("MALLOC_CHECK_", "2");
    try test_env.put("LINT_WARNINGS_ARE_ERRORS", "1");

    // Don’t build the tests unless we can run them (either natively, in an exe wrapper, or by installing them for later use)
    // const build_tests = enable_tests and (!run_test.skip_foreign_checks or installed_tests_enabled);

    // Disable strict aliasing;
    // see https://bugzilla.gnome.org/show_bug.cgi?id=791622
    var cflags: std.ArrayList([]const u8) = try .initCapacity(b.allocator, 24);
    cflags.appendSliceAssumeCapacity(&.{
        "-fno-strict-aliasing",
        "-D_XOPEN_SOURCE=800",
        "-Wall",
        "-Weverything",
        "-Wextra",
        "-Wno-c++98-compat",
        "-Wno-declaration-after-statement",
        "-Wno-pre-c2x-compat",
        "-Wno-pre-c2y-compat",
        "-Wno-switch-default",
        "-Wno-unsafe-buffer-usage",
        "-Wno-used-but-marked-unused",
        "-Wno-vla",
        "-Wno-unused-parameter",
        "-Wno-cast-function-type",
        // "-Wno-bad-function-cast",
        "-Wno-format-zero-length",
        "-Wno-variadic-macros",
        // "-Wno-string-plus-int",
        //  "-Wno-typedef-redefinition",
        "-pedantic",
        "-pedantic-errors",
        "-std=c2y",
        // Prevents the library(.so) from being unloaded from memory. Meaning
        // It would remains in the process's address space even when dlclose()
        // is called
        "-Wl,-z,nodelete",
    });

    // Bind references to global functions to within the library itself to make
    // function calls faster because the dynamic linker doesn't have to resolve
    // symbol at runtime via the Procedure Linkage Table (PLT)
    if (bsymbolic_functions) cflags.appendAssumeCapacity("-Wl,-Bsymbolic-functions");

    switch (optimize) {
        .Debug => cflags.appendAssumeCapacity("-DG_ENABLE_DEBUG"),
        else => cflags.appendAssumeCapacity("-DG_DISABLE_CAST_CHECKS"),
    }

    switch (rt.os.tag) {
        .linux => cflags.appendAssumeCapacity("-D_GNU_SOURCE"),
        .windows => cflags.appendSliceAssumeCapacity(&.{ "-DUNICODE", "-D_UNICODE", "-mms-bitfields" }),
        else => {},
    }
    if (!glib_assert) cflags.appendAssumeCapacity("-DG_DISABLE_ASSERT");
    if (!glib_checks) cflags.appendAssumeCapacity("-DG_DISABLE_CHECKS");

    // Versioning
    const version: std.SemanticVersion = try .parse(build_zon.version);
    const major_version = version.major;
    const minor_version = version.minor;
    const micro_version = version.patch;

    const interface_age = if (minor_version % 2 != 0) 0 else micro_version;
    const binary_age = 100 * minor_version + micro_version;
    const soversion = 0;
    const current = binary_age - interface_age;
    const library_version: std.SemanticVersion = .{ .major = soversion, .minor = current, .patch = interface_age };

    const glibconfig_conf = b.addConfigHeader(.{
        .style = .{
            .cmake = upstream.path("glib/glibconfig.h.in"),
        },
        .include_path = "glib/glibconfig.h",
    }, .{
        // used by the .rc.in files
        .LT_CURRENT_MINUS_AGE = soversion,
        .glib_os = switch (rt.os.tag) {
            .windows =>
            \\\#define G_OS_WIN32
            \\\#define G_PLATFORM_WIN32
            \\\
            ,
            .linux => "#define G_OS_UNIX",
            else => unreachable,
        },
    });

    switch (linkage) {
        .static => glibconfig_conf.addValues(.{
            .GLIB_STATIC_COMPILATION = 1,
            .GOBJECT_STATIC_COMPILATION = 1,
            .GIO_STATIC_COMPILATION = 1,
            .GMODULE_STATIC_COMPILATION = 1,
            .GI_STATIC_COMPILATION = 1,
            .G_INTL_STATIC_COMPILATION = 1,
            .FFI_STATIC_BUILD = 1,
        }),
        else => {},
    }

    const glib_conf = b.addConfigHeader(.{
        .style = .blank,
        .include_path = "glib/config.h",
    }, .{
        .GLIB_MAJOR_VERSION = int64(major_version),
        .GLIB_MINOR_VERSION = int64(minor_version),
        .GLIB_MICRO_VERSION = int64(micro_version),
        .GLIB_INTERFACE_AGE = int64(interface_age),
        .GLIB_BINARY_AGE = int64(binary_age),
        .GETTEXT_PACKAGE = "glib20",
        .PACKAGE_BUGREPORT = "https://github.com/bernardassan/Glib/issues/new",
        .PACKAGE_NAME = "glib",
        .PACKAGE_STRING = b.fmt("glib {s}", .{build_zon.version}),
        .PACKAGE_TARNAME = "glib",
        .PACKAGE_URL = "",
        .PACKAGE_VERSION = build_zon.version,
        .ENABLE_NLS = 1,
        ._GNU_SOURCE = 1,
        // Poll doesn't work on devices on Windows, and macOS's poll() implementation is known to be broken
        .BROKEN_POLL = switch (rt.os.tag) {
            .macos, .windows => true,
            else => false,
        },
        ._FILE_OFFSET_BITS = 64,
        // the Zig Mingw windows target is not UWP compatible
        ._WIN32_WINNT = switch (rt.os.tag) {
            .windows => "0x0601",
            else => null,
        },
    });
    //  check for header files
    platformHeadersConfig(glib_conf, b, &rt);
    if (glib_conf.values.contains("HAVE_LINUX_NETLINK_H") or
        glib_conf.values.contains("HAVE_NETLINK_NETLINK_H") or
        glib_conf.values.contains("HAVE_NETLINK_NETLINK_ROUTE_H")) glib_conf.addValue("HAVE_NETLINK", u32, 1);

    // TODO: improve feature detection to actually be able to tell support
    // without compiling code
    if (!rt.isBionicLibC()) glib_conf.addValue("HAVE_STATX", u32, 1);
    if (rt.os.tag != .windows) glib_conf.addValue("HAVE_LC_MESSAGES", u32, 1);
    //  check for struct members in libc
    platformStructMembersConfig(glib_conf, b, &rt);

    const glib_mod = b.createModule(.{
        .link_libc = true,
        .optimize = optimize,
        .target = target,
    });
    glib_mod.addIncludePath(upstream.path("."));
    glib_mod.addIncludePath(upstream.path("glib"));
    glib_mod.addIncludePath(upstream.path("gobject"));
    glib_mod.addIncludePath(upstream.path("gmodule"));
    glib_mod.addIncludePath(upstream.path("gio"));
    glib_mod.addIncludePath(upstream.path("girepository"));
    glib_mod.addConfigHeader(glib_conf);
    glib_mod.addConfigHeader(glibconfig_conf);
    const glib = b.addLibrary(.{
        .name = "glib-2.0",
        .root_module = glib_mod,
        .linkage = linkage,
        .max_rss = 1024 * 1024,
        .version = library_version,
    });
    _ = glib; // autofix

    // TODO: install library and include directories
}

fn platformHeadersConfig(glib_conf: *Step.ConfigHeader, b: *std.Build, rt: *const std.Target) void {
    for (headers.all_platforms) |header| {
        const define = headers.toDefine(b, header);
        glib_conf.addValue(define, u32, 1);
    }
    for (headers.no_platform) |header| {
        const define = headers.toDefine(b, header);
        glib_conf.addValue(define, @TypeOf(null), null);
    }
    if (rt.os.tag == .linux) for (headers.linux) |header| {
        const define = headers.toDefine(b, header);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.os.tag != .windows) for (headers.unix) |header| {
        const define = headers.toDefine(b, header);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isMinGW()) for (headers.mingw) |header| {
        const define = headers.toDefine(b, header);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isMuslLibC() or rt.isGnuLibC()) for (headers.musl_glibc) |header| {
        const define = headers.toDefine(b, header);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isMuslLibC() or rt.isGnuLibC() or rt.isFreeBSDLibC() or rt.isOpenBSDLibC())
        for (headers.musl_glibc_free_open_bsd) |header| {
            const define = headers.toDefine(b, header);
            glib_conf.addValue(define, u32, 1);
        };
    if (rt.isMuslLibC() or rt.isGnuLibC() or rt.isFreeBSDLibC())
        for (headers.musl_glibc_freebsd) |header| {
            const define = headers.toDefine(b, header);
            glib_conf.addValue(define, u32, 1);
        };
    if (rt.isDarwinLibC()) for (headers.darwin) |header| {
        const define = headers.toDefine(b, header);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isDarwinLibC() or rt.isFreeBSDLibC() or rt.isNetBSDLibC() or
        rt.isOpenBSDLibC())
        for (headers.darwin_all_bsd) |header| {
            const define = headers.toDefine(b, header);
            glib_conf.addValue(define, u32, 1);
        };
    if (rt.isDarwinLibC() or rt.isFreeBSDLibC()) for (headers.darwin_freebsd) |header| {
        const define = headers.toDefine(b, header);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isGnuLibC() or rt.isFreeBSDLibC() or rt.isNetBSDLibC() or
        rt.isOpenBSDLibC())
        for (headers.glibc_all_bsd) |header| {
            const define = headers.toDefine(b, header);
            glib_conf.addValue(define, u32, 1);
        };
    if (rt.isFreeBSDLibC()) for (headers.freebsd) |header| {
        const define = headers.toDefine(b, header);
        glib_conf.addValue(define, u32, 1);
    };
}

fn platformStructMembersConfig(glib_conf: *Step.ConfigHeader, b: *std.Build, rt: *const std.Target) void {
    for (struct_members.no_platform) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, @TypeOf(null), null);
    }
    if (rt.os.tag != .windows) for (struct_members.unix) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isDarwinLibC() or rt.isFreeBSDLibC() or rt.isNetBSDLibC()) for (struct_members.darwin_free_net_bsd) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isDarwinLibC() or rt.isFreeBSDLibC() or rt.isOpenBSDLibC()) for (struct_members.darwin_free_open_bsd) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isFreeBSDLibC()) for (struct_members.free_bsd) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isFreeBSDLibC() or rt.isNetBSDLibC()) for (struct_members.free_net_bsd) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isGnuLibC() or rt.isDarwinLibC() or rt.isFreeBSDLibC() or rt.isOpenBSDLibC() or rt.isNetBSDLibC()) for (struct_members.glibc_darwin_all_bsd) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isMuslLibC() or rt.isGnuLibC()) for (struct_members.musl_glibc) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isMuslLibC() or rt.isGnuLibC() or rt.isNetBSDLibC() or rt.isOpenBSDLibC() or rt.isFreeBSDLibC()) for (struct_members.musl_glibc_all_bsd) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isMuslLibC() or rt.isGnuLibC() or rt.isDarwinLibC() or rt.isNetBSDLibC() or rt.isOpenBSDLibC() or rt.isFreeBSDLibC())
        for (struct_members.musl_glibc_darwin_all_bsd) |member| {
            const define = struct_members.toDefine(b, member);
            glib_conf.addValue(define, u32, 1);
        };
    if (rt.isMuslLibC() or rt.isGnuLibC() or rt.isDarwinLibC() or rt.isFreeBSDLibC() or rt.isOpenBSDLibC()) for (struct_members.musl_glibc_darwin_free_open_bsd) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
    if (rt.isNetBSDLibC()) for (struct_members.net_bsd) |member| {
        const define = struct_members.toDefine(b, member);
        glib_conf.addValue(define, u32, 1);
    };
}

fn int64(value: anytype) i64 {
    return @intCast(value);
}

// The segregation of headers was done by manually checking for them in
// Zig's /lib/libc folder
const headers = struct {
    /// underscorify and to_upper
    fn toDefine(b: *std.Build, header: []const u8) []const u8 {
        const macro = b.fmt("HAVE_{s}", .{header});
        mem.replaceScalar(u8, macro, '.', '_');
        mem.replaceScalar(u8, macro, '/', '_');
        return std.ascii.upperString(macro, macro);
    }
    // musl, glibc, darwin, netbsd, freebsd, openbsd
    const unix: []const []const u8 = &.{
        "alloca.h",
        "grp.h",
        "poll.h",
        "pwd.h",
        "spawn.h",
        "sys/uio.h",
        "sys/mount.h",
        "sys/resource.h",
        "sys/select.h",
        "sys/statvfs.h",
        "sys/times.h",
        "sys/wait.h",
        "syslog.h",
        "termios.h",
    };

    const mingw: []const []const u8 = &.{
        "afunix.h",
        "intsafe.h",
    };

    const darwin: []const []const u8 = &.{
        "crt_externs.h",
        "libproc.h",
        "mach/mach_time.h",
    };

    const glibc_all_bsd: []const []const u8 = &.{
        "fstab.h",
    };

    const linux: []const []const u8 = &.{
        "linux/netlink.h",
    };

    const musl_glibc: []const []const u8 = &.{
        "mntent.h",
        "sys/statfs.h",
        "sys/prctl.h",
        "sys/vfs.h",
        "values.h",
    };

    const freebsd: []const []const u8 = &.{
        "netlink/netlink.h",
        "netlink/netlink_route.h",
        // Double check these
        "stdatomic.h",
        "stdckdint.h",
    };

    const musl_glibc_free_open_bsd: []const []const u8 = &.{
        "sys/auxv.h",
    };

    const musl_glibc_freebsd: []const []const u8 = &.{
        "sys/inotify.h",
    };

    const darwin_all_bsd: []const []const u8 = &.{
        "sys/event.h",
        "sys/filio.h",
        "sys/sysctl.h",
        "sys/ucred.h",
    };

    const darwin_freebsd: []const []const u8 = &.{
        "xlocale.h",
    };

    // no Zig platform currently has these headers
    const no_platform: []const []const u8 = &.{
        "sys/mkdev.h",
        "sys/mntctl.h",
        "sys/mnttab.h",
        "sys/vfstab.h",
        "sys/vmount.h",
    };

    const all_platforms: []const []const u8 = &.{
        "dirent.h",
        "float.h",
        "ftw.h",
        "inttypes.h",
        "limits.h",
        "locale.h",
        "memory.h",
        "sched.h",
        "stdint.h",
        "stdlib.h",
        "string.h",
        "strings.h",
        "sys/param.h",
        "sys/stat.h",
        "sys/time.h",
        "sys/types.h",
        "unistd.h",
        "wchar.h",
        "malloc.h",
    };
};

const struct_members = struct {
    /// underscorify and to_upper
    fn toDefine(b: *std.Build, member: []const u8) []const u8 {
        const macro = b.fmt("HAVE_STRUCT_{s}", .{member});
        mem.replaceScalar(u8, macro, '.', '_');
        return std.ascii.upperString(macro, macro);
    }

    const glibc_darwin_all_bsd: []const []const u8 = &.{
        "stat_st_mtimensec",
        "stat_st_atimensec",
        "stat_st_ctimensec",
    };

    // the glib support is on only few architectures
    // TODO: verify the glibc support for stat
    const musl_glibc_all_bsd: []const []const u8 = &.{
        "stat_st_mtim.tv_nsec",
        "stat_st_atim.tv_nsec",
        "stat_st_ctim.tv_nsec",
    };

    const musl_glibc_darwin_free_open_bsd: []const []const u8 = &.{
        "statfs_f_bavail",
    };

    const musl_glibc_darwin_all_bsd: []const []const u8 = &.{
        "dirent_d_type",
        "tm_tm_gmtoff",
    };

    const unix: []const []const u8 = &.{
        "stat_st_blksize",
        "stat_st_blocks",
    };

    const musl_glibc: []const []const u8 = &.{
        "statvfs_f_type",
        "tm___tm_gmtoff",
    };

    // TODO: test darwin and free_bsd members as I'm not too sure
    const darwin_free_net_bsd: []const []const u8 = &.{
        "stat_st_birthtime", // open bsd uses __st_birthtime
        "stat_st_birthtimensec", // open has __st_bi*
    };

    const darwin_free_open_bsd: []const []const u8 = &.{
        "statfs_f_fstypename",
    };

    const free_net_bsd: []const []const u8 = &.{
        "stat_st_birthtim", // openbsd uses __st_b*
    };

    const free_bsd: []const []const u8 = &.{
        "stat_st_birthtim.tv_nsec", // openbsd uses __st_b*
    };

    const net_bsd: []const []const u8 = &.{
        "statvfs_f_fstypename",
    };

    const no_platform: []const []const u8 = &.{
        "statvfs_f_basetype",
    };
};

const functions = struct {
    const unix: []const []const u8 = &.{
        "statvfs",
        "faccessat",
        "fchmod",
        "fchown",
        "getifaddrs",
        "lchown",
        "memmem",
        "mmap",
        "newlocale",
        "poll",
        "readlink",
        "setenv",
        "strnlen",
        "strsignal",
        "timegm",
        "unsetenv",
        "utimes",
        "utimensat",
        "valloc",
    };

    const musl_glibc: []const []const u8 = &.{
        "splice",
        "sysinfo",
        "prctl",
        "endmntent",
        "epoll_create1",
        "fallocate",
        "getauxval",
        "getmntent_r",
        "hasmntopt",
        "prlimit",
    };

    const musl_glibc_freebsd: []const []const u8 = &.{
        "copy_file_range",
        "inotify_init1",
        "memalign",
    };

    const musl_glibc_darwin_free_openbsd: []const []const u8 = &.{
        "statfs",
        "uselocale",
    };

    const musl_glibc_darwin_free_netbsd: []const []const u8 = &.{
        "lchmod",
        "strtod_l",
    };

    const musl_glibc_all_bsd: []const []const u8 = &.{
        "accept4",
        "pipe2",
        "recvmmsg",
        "sendmmsg",
    };

    const musl_glibc_free_openbsd: []const []const u8 = &.{
        "getresuid",
    };

    const musl_darwin_all_bsd: []const []const u8 = &.{
        "issetugid",
    };

    const darwin: []const []const u8 = &.{
        "_NSGetEnviron",
    };

    const darwin_free_openbsd: []const []const u8 = &.{
        "getfsstat",
    };

    const darwin_free_netbsd: []const []const u8 = &.{
        "sysctlbyname",
    };

    const darwin_all_bsd: []const []const u8 = &.{
        "kevent",
        "kqueue",
    };

    const glibc: []const []const u8 = &.{
        "free_aligned_sized",
        "free_sized",
    };

    const glibc_all_bsd: []const []const u8 = &.{
        "getfsent",
    };

    const glibc_darwin_free_netbsd: []const []const u8 = &.{
        "strtoll_l",
        "strtoull_l",
    };

    const glibc_freebsd: []const []const u8 = &.{
        "close_range",
    };

    const glibc_mingw: []const []const u8 = &.{
        "ftruncate64",
    };

    const netbsd: []const []const u8 = &.{
        "getvfsstat",
    };

    const no_platform: []const []const u8 = &.{
        "fdwalk",
        "setmntent",
    };

    // musl, glibc, darwin, mingw, freebsd, netbsd and openbsd
    const all_platforms: []const []const u8 = &.{
        "if_nametoindex",
        "if_indextoname",
        "endservent",
        "fsync",
        "getc_unlocked",
        "getgrgid_r",
        "getpwnam_r",
        "getpwuid_r",
        "gmtime_r",
        "link",
        "localtime_r",
        "lstat",
        "mbrtowc",
        "strerror_r",
        "symlink",
        "vasprintf",
        "vsnprintf",
        "wcrtomb",
        "wcslen",
        "wcsnlen",
    };
};
