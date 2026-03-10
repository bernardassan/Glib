const std = @import("std");
const build_zon = @import("build.zig.zon");
const builtin = @import("builtin");
const debug = std.debug;

const platform = @import("build/platform.zig");
const headers = platform.headers;
const struct_members = platform.struct_members;
const functions = platform.functions;
const is = platform.is;

const glib = @import("build/glib.zig");

const Buildtype = enum { debugoptimized };
const WarnLevel = enum { @"1", @"2", @"3" };
// TODO: make c11 default and try higer versions to see if they compile
const Cstd = enum { gnu99, c99, c11, c17, c23 };
const Feature = enum { enabled, disabled, auto };
const MonitorBackend = enum { auto, inotify, kqueue, @"libinotify-kqueue", win32 };

// TODO: verify all quoted configs are quoted as necessary
pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const rt = target.result;

    switch (rt.os.tag) {
        .windows, .macos, .linux, .freebsd, .netbsd, .openbsd => {},
        else => @panic("Os not supported. Contributions are welcome"),
    }

    // we only support systems where short is 2 bytes and int 4 bytes
    debug.assert(rt.cTypeByteSize(.short) == 2);
    debug.assert(rt.cTypeByteSize(.int) == 4);

    const upstream = b.dependency("glib2", .{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "linkage mode for library") orelse .static;

    const gio_module_dir = b.option([]const u8, "gio_module_dir", "load gio modules from this directory (default to '${libdir}/gio/modules' if unset)");
    const selinux = b.option(Feature, "selinux", "build with selinux support") orelse .auto;
    _ = selinux; // autofix

    const xattr = b.option(bool, "xattr", "build with xattr support") orelse true;

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
    default_options.addOption(bool, "have_dlopen_dlsym", rt.os.tag != .windows);

    const glib_prefix = b.install_path;
    const glib_bindir = b.exe_dir;
    _ = glib_bindir; // autofix
    const glib_libdir = b.lib_dir;
    const includedir = b.h_dir;
    const libexecdir = b.pathJoin(&.{ glib_libdir, "libexec" });
    const datadir = b.pathJoin(&.{ glib_prefix, "share" });
    const glib_localedir = b.pathJoin(&.{ glib_prefix, "share/locale" });
    const glib_localstatedir = b.pathJoin(&.{ glib_prefix, "state" });
    const glib_libexecdir = b.pathJoin(&.{ glib_prefix, libexecdir });
    const glib_datadir = b.pathJoin(&.{ glib_prefix, datadir });
    const glib_pkgdatadir = b.pathJoin(&.{ glib_datadir, "glib-2.0" });
    _ = glib_pkgdatadir; // autofix
    const glib_includedir = b.pathJoin(&.{ glib_prefix, includedir, "glib-2.0" });
    _ = glib_includedir; // autofix
    const glib_giomodulesdir = if (gio_module_dir) |gio_modules_dir| b.pathJoin(&.{ glib_prefix, gio_modules_dir }) else b.pathJoin(&.{ glib_libdir, "gio", "modules" });
    _ = glib_giomodulesdir; // autofix

    const glib_pkgconfigreldir = b.pathJoin(&.{ glib_libdir, "pkgconfig" });
    _ = glib_pkgconfigreldir; // autofix

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

    var cflags: std.ArrayList([]const u8) = try .initCapacity(b.allocator, 48);
    cflags.appendSliceAssumeCapacity(&.{
        "-std=c2y",
        // Disable strict aliasing;
        // see https://bugzilla.gnome.org/show_bug.cgi?id=791622
        "-fno-strict-aliasing",
        "-D_XOPEN_SOURCE=800",
        "-Wall",
        "-Wextra",
        "-Wduplicated-branches",
        "-Wfloat-conversion",
        "-Wimplicit-fallthrough",
        "-Wmisleading-indentation",
        "-Wmissing-field-initializers",
        "-Wnonnull",
        "-Wnull-dereference",
        "-Wunused",
        // Due to maintained deprecated code, we do not want to see unused
        // parameters
        "-Wno-unused-parameter",
        // Due to pervasive use of things like GPOINTER_TO_UINT(), we do not
        // support building with -Wbad-function-cast.
        "-Wno-cast-function-type",
        // Due to function casts through (void*) we cannot support -Wpedantic:
        // ./docs/toolchain-requirements.md#Function_pointer_conversions.
        "-Wno-pedantic",
        // A zero-length format string shouldn't be considered an issue.
        "-Wno-format-zero-length",
        // We explicitly require variadic macros
        "-Wno-variadic-macros",
        "-Werror=format=2",
        "-Werror=init-self",
        "-Werror=missing-include-dirs",
        "-Werror=pointer-arith",
        "-Werror=unused-result",
        "-Wstrict-prototypes",
        // Due to pervasive use of things like GPOINTER_TO_UINT(), we do not
        // support building with -Wbad-function-cast.
        "-Wno-bad-function-cast",
        "-Werror=implicit-function-declaration",
        "-Werror=missing-prototypes",
        "-Werror=pointer-sign",
        "-Wno-string-plus-int",
        // We require a compiler that supports C11 even though it's not yet a
        // strict requirement, so allow typedef redefinition not to break clang
        // and older gcc versions.
        "-Wno-typedef-redefinition",
        // FIXME: See https://gitlab.gnome.org/GNOME/glib/-/issues/3405
        "-Wsign-conversion",
        // FIXME: See https://gitlab.gnome.org/GNOME/glib/-/issues/3527
        "-Wshorten-64-to-32",
    });

    if (rt.isMinGW()) cflags.appendSliceAssumeCapacity(&.{
        "-lws2_32", "-lole32", "-lwinmm", "-lshlwapi", "-luuid",
    });

    switch (linkage) {
        .dynamic => {
            switch (rt.os.tag) {
                .linux => {
                    // Prevents the library(.so) from being unloaded from
                    // memory. Meaning It would remains in the process's
                    // address space even when dlclose() is called
                    cflags.appendAssumeCapacity("-Wl,-z,nodelete");
                    // Bind references to global functions to within the
                    // library itself to make function calls faster because the
                    // dynamic linker doesn't have to resolve symbol at runtime
                    // via the Procedure Linkage Table (PLT)
                    if (bsymbolic_functions) cflags.appendAssumeCapacity("-Wl,-Bsymbolic-functions");
                },
                else => {},
            }
        },
        else => {},
    }

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

    const noop = .@"/* NOOP */";
    const glibconfig_conf = b.addConfigHeader(.{
        .style = .{
            .meson = upstream.path("glib/glibconfig.h.in"),
        },
    }, .{
        .GLIB_MAJOR_VERSION = int64(major_version),
        .GLIB_MINOR_VERSION = int64(minor_version),
        .GLIB_MICRO_VERSION = int64(micro_version),
        .glib_os = switch (rt.os.tag) {
            .windows => "#define G_OS_WIN32\n#define G_PLATFORM_WIN32",
            else => "#define G_OS_UNIX",
        },
        .glib_vacopy = noop,
        .G_HAVE_FREE_SIZED = if (rt.isGnuLibC()) true else null,
        .gint16 = .short,
        .gint16_modifier = quote("h"),
        .gint16_format = quote("hi"),
        .guint16_format = quote("hu"),
        .gint32 = .int,
        .gint32_modifier = noop,
        .gint32_format = quote("i"),
        .guint32_format = quote("u"),
        .gintbits = rt.cTypeBitSize(.int),
        .glongbits = rt.cTypeBitSize(.long),
        .gsizebits = rt.ptrBitWidth(),
        .g_module_suffix = if (rt.isMinGW()) "dll" else "so",
        .glib_void_p = rt.ptrBitWidth() / 8,
        .glib_long = rt.cTypeByteSize(.long),
        .glib_size_t = rt.ptrBitWidth() / 8,
        .glib_ssize_t = rt.ptrBitWidth() / 8,
        .GLIB_HAVE_ALLOCA_H = if (!rt.isMinGW()) true else false,
        // Unix has these poll values and it windows builds uses same for abi
        // compatibility due to historical bug
        .g_pollin = 1,
        .g_pollpri = 2,
        .g_pollout = 4,
        .g_pollerr = 8,
        .g_pollhup = 16,
        .g_pollnval = 32,
        // Inet defines
        .g_af_unix = 1,
        .g_af_inet = 2,
        .g_af_inet6 = if (is(&rt, &.{ .musl, .gnu }))
            int64(10)
        else if (rt.isDarwinLibC())
            int64(30)
        else if (rt.isMinGW())
            int64(23)
        else if (is(&rt, &.{ .openbsd, .netbsd }))
            int64(24)
        else if (rt.isFreeBSDLibC()) 28 else unreachable,
        .g_msg_oob = 1,
        .g_msg_peek = 2,
        .g_msg_dontroute = 4,
        .G_ATOMIC_LOCK_FREE = true,
        // support only systems where stack grows downward
        .G_HAVE_GROWING_STACK = false,
    });

    switch (rt.cpu.arch.endian()) {
        .little => glibconfig_conf.addValues(.{
            .g_byte_order = .G_LITTLE_ENDIAN,
            .g_bs_native = .LE,
            .g_bs_alien = .BE,
        }),
        .big => glibconfig_conf.addValues(.{
            .g_byte_order = .G_BIG_ENDIAN,
            .g_bs_native = .BE,
            .g_bs_alien = .LE,
        }),
    }

    if (rt.cTypeByteSize(.long) == 8)
        glibconfig_conf.addValues(.{
            .gint64 = .long,
            .glib_extension = noop,
            .gint64_modifier = quote("l"),
            .gint64_format = quote("li"),
            .guint64_format = quote("lu"),
            .gint64_constant = .@"(val##L)",
            .guint64_constant = .@"(val##UL)",
        })
    else
        glibconfig_conf.addValues(.{
            .gint64 = .@"long long",
            .glib_extension = .G_GNUC_EXTENSION,
            .gint64_modifier = quote("ll"),
            .gint64_format = quote("lli"),
            .guint64_format = quote("llu"),
            .gint64_constant = .@"(G_GNUC_EXTENSION (val##LL))",
            .guint64_constant = .@"(G_GNUC_EXTENSION (val##ULL))",
        });

    switch (rt.os.tag) {
        .windows => {
            glibconfig_conf.addValues(.{
                .g_pid_type = .@"void*",
                .g_pid_format = "p",
                .g_dir_separator = .@"\\\\",
                .g_searchpath_separator = .@";",
                .glib_size_type_define = .@"long long",
                .gsize_modifier = quote("ll"),
                .gssize_modifier = quote("ll"),
                .gsize_format = quote("llu"),
                .gssize_format = quote("lli"),
                .glib_msize_type = .INT64,
                .glib_intptr_type_define = .@"long long",
                .gintptr_modifier = quote("ll"),
                .gintptr_format = quote("lli"),
                .guintptr_format = quote("llu"),
                .glib_gpi_cast = .@"(gint64)",
                .glib_gpui_cast = .@"(guint64)",
                .g_pollfd_format = switch (rt.cpu.arch) {
                    .aarch64, .x86_64 => quote("%#llx"),
                    else => quote("%#x"),
                },
            });
        },
        else => {
            glibconfig_conf.addValues(.{
                .g_pid_type = .int,
                .g_pid_format = quote("i"),
                .g_pollfd_format = quote("%d"),
                .g_dir_separator = .@"/",
                .g_searchpath_separator = .@":",
                .glib_size_type_define = .long,
                .gsize_modifier = quote("l"),
                .gssize_modifier = quote("l"),
                .gsize_format = quote("lu"),
                .gssize_format = quote("li"),
                .glib_msize_type = .LONG,
                .glib_intptr_type_define = .long,
                .gintptr_modifier = quote("l"),
                .gintptr_format = quote("li"),
                .guintptr_format = quote("lu"),
                .glib_gpi_cast = .@"(glong)",
                .glib_gpui_cast = .@"(gulong)",
            });
        },
    }

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
        .include_path = "config.h",
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
        .ENABLE_NLS = true,
        ._GNU_SOURCE = true,
        // Poll doesn't work on devices on Windows, and macOS's poll() implementation is known to be broken
        .BROKEN_POLL = switch (rt.os.tag) {
            .macos, .windows => true,
            else => false,
        },
        ._FILE_OFFSET_BITS = 64,
        // the Zig Mingw windows target is not UWP compatible
        ._WIN32_WINNT = switch (rt.os.tag) {
            .windows => int64(0x0601),
            else => null,
        },
        .EXEEXT = switch (rt.os.tag) {
            .windows => quote(".exe"),
            else => null,
        },
        .MAJOR_IN_TYPES = if (is(&rt, &.{ .darwin, .freebsd, .openbsd, .netbsd })) true else null,
        // the clang bundled with Zig version `build_zon.minimum_zig_version`
        // supports __uint128_t
        .HAVE_UINT128_T = true,
        .HAVE_PTRDIFF_T = true,
        .HAVE_SIG_ATOMIC_T = true,
        .GLIB_LOCALE_DIR = glib_localedir,
        .GLIB_LOCALSTATEDIR = glib_localstatedir,
        .GLIB_RUNSTATEDIR = quote("/run"),
        .HAVE_PROC_SELF_CMDLINE = if (rt.os.tag == .linux) true else false,
        ._XOPEN_SOURCE = 800,
        .__EXTENSIONS__ = true,
        .HAVE__CRT_SET_REPORT_MODE = if (rt.isMinGW()) true else false,
        .HAVE_IPV6 = true,
        // only used by the .rc.in files
        .LT_CURRENT_MINUS_AGE = soversion,
    });

    // xattr
    if (!rt.isMinGW() and xattr) if (is(&rt, &.{ .musl, .gnu, .netbsd })) glib_conf.addValues(.{
        .HAVE_SYS_XATTR_H = true,
        .HAVE_XATTR = true,
    });

    // Thread implementation
    switch (rt.os.tag) {
        .windows => {
            glibconfig_conf.addValues(.{ .g_threads_impl_def = .WIN32 });
            glib_conf.addValues(.{ .THREADS_WIN32 = true });
        },
        else => |oses| {
            glibconfig_conf.addValues(.{ .g_threads_impl_def = .POSIX });
            glib_conf.addValues(.{
                .THREADS_POSIX = true,
                // all supported platforms have this
                .HAVE_PTHREAD_ATTR_SETSTACKSIZE = true,
                .HAVE_PTHREAD_ATTR_SETINHERITSCHED = true,
                // all but darwin
                .HAVE_PTHREAD_CONDATTR_SETCLOCK = if (!rt.isDarwinLibC()) true else false,
                // Only on darwin and mingw
                .HAVE_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP = if (rt.isDarwinLibC()) true else false,
                // all but openbsd
                .HAVE_PTHREAD_GETNAME_NP = if (!rt.isOpenBSDLibC()) true else false,
                // only on musl, glibc, netbsd and freebsd
                .HAVE_PTHREAD_GETAFFINITY_NP = if (!(rt.isOpenBSDLibC() or rt.isDarwinLibC())) true else false,
            });

            switch (oses) {
                .macos => glib_conf.addValues(.{
                    .HAVE_PTHREAD_SETNAME_NP_WITHOUT_TID = true,
                }),
                .linux, .freebsd => glib_conf.addValues(.{
                    .HAVE_PTHREAD_SETNAME_NP_WITH_TID = true,
                }),
                .netbsd => glib_conf.addValues(.{
                    .HAVE_PTHREAD_SETNAME_NP_WITH_TID_AND_ARG = true,
                }),
                .openbsd => glib_conf.addValues(.{
                    .HAVE_PTHREAD_SET_NAME_NP = true,
                }),
                else => unreachable,
            }
        },
    }

    // libintl
    if (is(&rt, &.{ .musl, .gnu })) {
        glib_conf.addValues(.{
            .HAVE_BIND_TEXTDOMAIN_CODESET = true,
        });
    }

    // gettext is required to be always present
    glib_conf.addValues(.{
        .HAVE_DCGETTEXT = true,
        .HAVE_GETTEXT = true,
    });

    glib_conf.addValues(.{
        .SIZEOF_CHAR = rt.cTypeByteSize(.char),
        .SIZEOF_INT = rt.cTypeByteSize(.int),

        .SIZEOF_SHORT = rt.cTypeByteSize(.short),
        .SIZEOF_LONG = rt.cTypeByteSize(.long),
        .SIZEOF_LONG_LONG = rt.cTypeByteSize(.longlong),
        .SIZEOF_SIZE_T = rt.ptrBitWidth() / 8,
        .SIZEOF_SSIZE_T = rt.ptrBitWidth() / 8,
        .SIZEOF_VOID_P = rt.ptrBitWidth() / 8,
        .SIZEOF_WCHAR_T = if (!rt.isMinGW()) int64(4) else int64(2),
    });

    if (rt.isGnuLibC()) glib_conf.addValues(.{
        .STRERROR_R_CHAR_P = true,
        .HAVE_LOFF_T = true,
        .HAVE_LANGINFO_ERA = true,
        .HAVE_LANGINFO_OUTDIGIT = true,
        .HAVE_LANGINFO_ABALTMON = true,
        .HAVE_LANGINFO_TIME_CODESET = true,
        .HAVE_LONG_LONG = true,
        .HAVE_LONG_DOUBLE = true,
        .HAVE_WCHAR_T = true,
        .HAVE_WINT_T = true,
        .HAVE_INTTYPES_H_WITH_UINTMAX = true,
        .HAVE_STDINT_H_WITH_UINTMAX = true,
        .HAVE_INTMAX_T = true,
    });

    if (rt.isGnuLibC() or rt.isMuslLibC()) glib_conf.addValues(.{
        .MAJOR_IN_SYSMACROS = true,
        .HAVE_UNSHARE = true,
    });

    if (rt.isGnuLibC() or rt.isFreeBSDLibC()) glib_conf.addValues(.{
        .HAVE_LANGINFO_ALTMON = true,
    });

    if (rt.isDarwinLibC()) glib_conf.addValues(.{
        .HAVE_FCNTL_F_FULLFSYNC = true,
    });
    // on platforms where `statfs.f_bavail` exist use the `statfs` syscall
    // directly as seen in  `struct_members.musl_glibc_darwin_free_open_bsd`
    if (is(&rt, &.{ .musl, .gnu, .darwin, .freebsd, .openbsd }))
        glib_conf.addValues(.{
            .USE_STATFS = true,
            .STATFS_ARGS = 2,
        });

    if (is(&rt, &.{.unix}))
        glib_conf.addValues(.{
            .HAVE_OPEN_O_DIRECTORY = true,
            .HAVE_C99_SNPRINTF = true,
            .HAVE_C99_VSNPRINTF = true,
            .HAVE_UNIX98_PRINTF = true,
            .USE_SYSTEM_PRINTF = true,
            .HAVE_LANGINFO_CODESET = true,
            .HAVE_CODESET = true,
            .HAVE_LANGINFO_TIME = true,
        });

    if (glib_conf.values.contains("USE_SYSTEM_PRINTF")) {
        glibconfig_conf.addValues(.{
            .GLIB_USING_SYSTEM_PRINTF = true,
        });
        glib_conf.addValues(.{
            .gl_unused = {},
            .gl_extern_inline = {},
        });
    }

    if (!glib_conf.values.get("USE_SYSTEM_PRINTF").?.boolean)
        glib_conf.addValues(.{
            .HAVE_VASPRINTF = true,
        });

    //  check for header files
    headers.config(glib_conf, b, &rt);

    if (glib_conf.values.contains("HAVE_LINUX_NETLINK_H") or
        glib_conf.values.contains("HAVE_NETLINK_NETLINK_H") or
        glib_conf.values.contains("HAVE_NETLINK_NETLINK_ROUTE_H"))
        glib_conf.addValue("HAVE_NETLINK", u32, 1);

    // TODO: improve feature detection to actually be able to tell support
    // without compiling code
    if (!rt.isBionicLibC()) glib_conf.addValue("HAVE_STATX", u32, 1);
    if (rt.os.tag != .windows) glib_conf.addValue("HAVE_LC_MESSAGES", u32, 1);

    //  check for struct members in libc
    struct_members.config(glib_conf, b, &rt);

    //  check for functions in libc
    functions.config(glib_conf, b, &rt);

    switch (builtin.os.tag) {
        // TODO: handle compiling with -framework Foundation and AppKit
        // and this requires objectivec
        .macos => glib_conf.addValues(.{
            // .HAVE_CARBON = true,
            // .HAVE_COCOA = true,
        }),
        .linux => glib_conf.addValues(.{
            .HAVE_FUTEX = true,
        }),
        else => {},
    }

    if (rt.os.tag == .linux and rt.ptrBitWidth() == 32) glib_conf.addValues(.{
        .HAVE_FUTEX_TIME64 = true,
    });

    // TODO: install library and include directories
    try glib.build(b, .{
        .version = version,
        .library_version = library_version,
        .cflags = &cflags,
        .linkage = linkage,
        .optimize = optimize,
        .target = target,
        .upstream = upstream,
        .glibconfig_conf = glibconfig_conf,
        .glib_conf = glib_conf,
    });
}

fn int64(value: anytype) i64 {
    return @intCast(value);
}

fn quote(comptime value: []const u8) []const u8 {
    return "\"" ++ value ++ "\"";
}
