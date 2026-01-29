const std = @import("std");
const builtin = @import("builtin");

const Buildtype = enum { debugoptimized };
const WarnLevel = enum { @"1", @"2", @"3" };
const Cstd = enum { gnu99, c99, c11, c17, c23 }; // TODO: make c11 default and try higer versions to see if they compile
const Feature = enum { enabled, disabled, auto };
const MonitorBackend = enum { auto, inotify, kqueue, @"libinotify-kqueue", win32 };

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    _ = optimize; // autofix
    const target = b.standardTargetOptions(.{});
    _ = target; // autofix

    const glib2 = b.dependency("glib2", .{});
    _ = glib2; // autofix

    const default_options = b.addOptions();
    default_options.addOption(Buildtype, "buildtype", .debugoptimized);
    default_options.addOption(WarnLevel, "warnlevel", .@"3");
    default_options.addOption(Cstd, "c_std", .c11);

    const gio_module_dir = b.option([]const u8, "gio_module_dir", "load gio modules from this directory (default to 'libdir/gio/modules' if unset)") orelse "libdir/gio/modules";
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
    const buld_tests = b.option(bool, "tests", "build tests") orelse true;
    _ = buld_tests; // autofix

    const installed_tests = b.option(bool, "installed_tests", "enable installed tests") orelse false;

    const nls = b.option(Feature, "nls", "Enable native language support (translations)") orelse .auto;
    _ = nls; // autofix

    const oss_fuzz = b.option(Feature, "oss_fuzz", "Indicate oss-fuzz build environment") orelse .disabled;
    _ = oss_fuzz; // autofix
    _ = installed_tests; // autofix
    _ = force_posix_threads; // autofix
    _ = bsymbolic_functions; // autofix
    _ = documentation; // autofix
    _ = sysprof; // autofix
    _ = tapset_install_dir; // autofix
    _ = man_pages; // autofix
    const glib_debug = b.option(Feature, "glib_debug", "Enable GLib debug infrastructure (distros typically want this disabled in production; see docs/macros.md)") orelse .enabled;
    _ = glib_debug; // autofix

    const glib_assert = b.option(bool, "glib_assert", "Enable GLib assertion (see docs/macros.md)") orelse true;
    _ = glib_assert; // autofix

    const glib_checks = b.option(bool, "glib_checks", "Enable GLib checks such as API guards (see docs/macros.md)") orelse true;
    _ = glib_checks; // autofix

    const libelf = b.option(Feature, "libelf", "Enable support for listing and extracting from ELF resource files with gresource tool") orelse .auto;
    _ = libelf; // autofix
    const gir_dir_prefix = b.option([]const u8, "gir_dir_prefix", "Intermediate prefix for gir installation under ${prefix}");
    _ = gir_dir_prefix; // autofix
    const introspection = b.option(Feature, "introspection", "Enable generating introspection data (requires gobject-introspection)") orelse
        .auto;
    const file_monitor_backend = b.option(MonitorBackend, "file_monitor_backend", "The name of the system API to use as a GFileMonitor backend") orelse .auto;
    _ = file_monitor_backend; // autofix
    _ = introspection; // autofix
    _ = gio_module_dir; // autofix
}
