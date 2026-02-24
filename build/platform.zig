const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const Step = std.Build.Step;
const Target = std.Target;

// The segregation of headers was done by manually checking for them in
// Zig's /lib/libc folder
pub const headers = struct {
    /// underscorify and to_upper
    pub fn toDefine(b: *std.Build, header: []const u8) []const u8 {
        const macro = b.fmt("HAVE_{s}", .{header});
        mem.replaceScalar(u8, macro, '.', '_');
        mem.replaceScalar(u8, macro, '/', '_');
        return std.ascii.upperString(macro, macro);
    }

    pub fn config(glib_conf: *Step.ConfigHeader, b: *std.Build, rt: *const std.Target) void {
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
        if (is(rt, &.{ .musl, .gnu, .freebsd, .openbsd }))
            for (headers.musl_glibc_free_open_bsd) |header| {
                const define = headers.toDefine(b, header);
                glib_conf.addValue(define, u32, 1);
            };
        if (is(rt, &.{ .musl, .gnu, .freebsd }))
            for (headers.musl_glibc_freebsd) |header| {
                const define = headers.toDefine(b, header);
                glib_conf.addValue(define, u32, 1);
            };
        if (rt.isDarwinLibC()) for (headers.darwin) |header| {
            const define = headers.toDefine(b, header);
            glib_conf.addValue(define, u32, 1);
        };
        if (is(rt, &.{ .darwin, .freebsd, .openbsd, .netbsd }))
            for (headers.darwin_all_bsd) |header| {
                const define = headers.toDefine(b, header);
                glib_conf.addValue(define, u32, 1);
            };
        if (rt.isDarwinLibC() or rt.isFreeBSDLibC()) for (headers.darwin_freebsd) |header| {
            const define = headers.toDefine(b, header);
            glib_conf.addValue(define, u32, 1);
        };
        if (is(rt, &.{ .gnu, .freebsd, .openbsd, .netbsd }))
            for (headers.glibc_all_bsd) |header| {
                const define = headers.toDefine(b, header);
                glib_conf.addValue(define, u32, 1);
            };
        if (rt.isFreeBSDLibC()) for (headers.freebsd) |header| {
            const define = headers.toDefine(b, header);
            glib_conf.addValue(define, u32, 1);
        };
    }

    // musl, glibc, darwin, netbsd, freebsd, openbsd
    pub const unix: []const []const u8 = &.{
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

    pub const mingw: []const []const u8 = &.{
        "afunix.h",
        "intsafe.h",
    };

    pub const darwin: []const []const u8 = &.{
        "crt_externs.h",
        "libproc.h",
        "mach/mach_time.h",
    };

    pub const glibc_all_bsd: []const []const u8 = &.{
        "fstab.h",
    };

    pub const linux: []const []const u8 = &.{
        "linux/netlink.h",
    };

    pub const musl_glibc: []const []const u8 = &.{
        "mntent.h",
        "sys/statfs.h",
        "sys/prctl.h",
        "sys/vfs.h",
        "values.h",
    };

    pub const freebsd: []const []const u8 = &.{
        "netlink/netlink.h",
        "netlink/netlink_route.h",
        // Double check these
        "stdatomic.h",
        "stdckdint.h",
    };

    pub const musl_glibc_free_open_bsd: []const []const u8 = &.{
        "sys/auxv.h",
    };

    pub const musl_glibc_freebsd: []const []const u8 = &.{
        "sys/inotify.h",
    };

    pub const darwin_all_bsd: []const []const u8 = &.{
        "sys/event.h",
        "sys/filio.h",
        "sys/sysctl.h",
        "sys/ucred.h",
    };

    pub const darwin_freebsd: []const []const u8 = &.{
        "xlocale.h",
    };

    // no Zig platform currently has these headers
    pub const no_platform: []const []const u8 = &.{
        "sys/mkdev.h",
        "sys/mntctl.h",
        "sys/mnttab.h",
        "sys/vfstab.h",
        "sys/vmount.h",
    };

    pub const all_platforms: []const []const u8 = &.{
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

pub const struct_members = struct {
    /// underscorify and to_upper
    pub fn toDefine(b: *std.Build, member: []const u8) []const u8 {
        const macro = b.fmt("HAVE_STRUCT_{s}", .{member});
        mem.replaceScalar(u8, macro, '.', '_');
        return std.ascii.upperString(macro, macro);
    }

    pub fn config(glib_conf: *Step.ConfigHeader, b: *std.Build, rt: *const std.Target) void {
        for (struct_members.no_platform) |member| {
            const define = struct_members.toDefine(b, member);
            glib_conf.addValue(define, @TypeOf(null), null);
        }
        if (rt.os.tag != .windows) for (struct_members.unix) |member| {
            const define = struct_members.toDefine(b, member);
            glib_conf.addValue(define, u32, 1);
        };
        if (is(rt, &.{ .darwin, .freebsd, .netbsd }))
            for (struct_members.darwin_free_net_bsd) |member| {
                const define = struct_members.toDefine(b, member);
                glib_conf.addValue(define, u32, 1);
            };
        if (is(rt, &.{ .darwin, .freebsd, .openbsd }))
            for (struct_members.darwin_free_open_bsd) |member| {
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
        if (is(rt, &.{ .gnu, .darwin, .freebsd, .openbsd, .netbsd }))
            for (struct_members.glibc_darwin_all_bsd) |member| {
                const define = struct_members.toDefine(b, member);
                glib_conf.addValue(define, u32, 1);
            };
        if (rt.isMuslLibC() or rt.isGnuLibC()) for (struct_members.musl_glibc) |member| {
            const define = struct_members.toDefine(b, member);
            glib_conf.addValue(define, u32, 1);
        };
        if (is(rt, &.{ .musl, .gnu, .freebsd, .openbsd, .netbsd }))
            for (struct_members.musl_glibc_all_bsd) |member| {
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

    pub const glibc_darwin_all_bsd: []const []const u8 = &.{
        "stat_st_mtimensec",
        "stat_st_atimensec",
        "stat_st_ctimensec",
    };

    // the glib support is on only few architectures
    // TODO: verify the glibc support for stat
    pub const musl_glibc_all_bsd: []const []const u8 = &.{
        "stat_st_mtim.tv_nsec",
        "stat_st_atim.tv_nsec",
        "stat_st_ctim.tv_nsec",
    };

    pub const musl_glibc_darwin_free_open_bsd: []const []const u8 = &.{
        "statfs_f_bavail",
    };

    pub const musl_glibc_darwin_all_bsd: []const []const u8 = &.{
        "dirent_d_type",
        "tm_tm_gmtoff",
    };

    pub const unix: []const []const u8 = &.{
        "stat_st_blksize",
        "stat_st_blocks",
    };

    pub const musl_glibc: []const []const u8 = &.{
        "statvfs_f_type",
        "tm___tm_gmtoff",
    };

    // TODO: test darwin and free_bsd members as I'm not too sure
    pub const darwin_free_net_bsd: []const []const u8 = &.{
        "stat_st_birthtime", // open bsd uses __st_birthtime
        "stat_st_birthtimensec", // open has __st_bi*
    };

    pub const darwin_free_open_bsd: []const []const u8 = &.{
        "statfs_f_fstypename",
    };

    pub const free_net_bsd: []const []const u8 = &.{
        "stat_st_birthtim", // openbsd uses __st_b*
    };

    pub const free_bsd: []const []const u8 = &.{
        "stat_st_birthtim.tv_nsec", // openbsd uses __st_b*
    };

    pub const net_bsd: []const []const u8 = &.{
        "statvfs_f_fstypename",
    };

    pub const no_platform: []const []const u8 = &.{
        "statvfs_f_basetype",
    };
};

pub const functions = struct {
    /// to_upper
    pub fn toDefine(b: *std.Build, function: []const u8) []const u8 {
        const macro = b.fmt("HAVE_{s}", .{function});
        return std.ascii.upperString(macro, macro);
    }

    pub const mingw: []const []const u8 = &.{
        "_aligned_malloc",
        "_set_invalid_parameter_handler",
    };

    pub const unix: []const []const u8 = &.{
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
        "stpcpy",
        "aligned_alloc",
        "posix_memalign",
        "RTLD_LAZY", // RTLD_LAZY symbol in dlfcn.h
        "RTLD_NOW",
        "RTLD_GLOBAL",
        "RTLD_NEXT",
        "mkostemp",
        "clock_gettime",
        "strlcpy",
    };

    pub const musl_glibc: []const []const u8 = &.{
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
        "pidfd", // pidfd_open(2) system call
    };

    pub const musl_glibc_freebsd: []const []const u8 = &.{
        "copy_file_range",
        "inotify_init1",
        "memalign",
        "getservbyname_r", // openbsd's getservbyname_r signature is different
    };

    pub const musl_glibc_darwin_free_openbsd: []const []const u8 = &.{
        "statfs",
        "uselocale",
    };

    pub const musl_glibc_darwin_free_netbsd: []const []const u8 = &.{
        "lchmod",
        "strtod_l",
    };

    pub const musl_glibc_all_bsd: []const []const u8 = &.{
        "accept4",
        "pipe2",
        "recvmmsg",
        "sendmmsg",
        "ppoll",
    };

    pub const musl_glibc_free_openbsd: []const []const u8 = &.{
        "getresuid",
    };

    pub const musl_glibc_free_netbsd: []const []const u8 = &.{
        "eventfd", // eventfd in sys/eventfd.h
    };

    pub const musl_darwin_all_bsd: []const []const u8 = &.{
        "issetugid",
    };

    pub const darwin: []const []const u8 = &.{
        "_NSGetEnviron",
    };

    pub const darwin_free_openbsd: []const []const u8 = &.{
        "getfsstat",
    };

    pub const darwin_free_netbsd: []const []const u8 = &.{
        "sysctlbyname",
    };

    pub const darwin_all_bsd: []const []const u8 = &.{
        "kevent",
        "kqueue",
    };

    pub const glibc: []const []const u8 = &.{
        "free_aligned_sized",
        "free_sized",
    };

    pub const glibc_all_bsd: []const []const u8 = &.{
        "getfsent",
    };

    pub const glibc_darwin_free_netbsd: []const []const u8 = &.{
        "strtoll_l",
        "strtoull_l",
    };

    pub const glibc_freebsd: []const []const u8 = &.{
        "close_range",
    };

    pub const glibc_mingw: []const []const u8 = &.{
        "ftruncate64",
    };

    pub const netbsd: []const []const u8 = &.{
        "getvfsstat",
    };

    pub const no_platform: []const []const u8 = &.{
        "fdwalk",
        "setmntent",
    };

    // musl, glibc, darwin, mingw, freebsd, netbsd and openbsd
    pub const all_platforms: []const []const u8 = &.{
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
        "posix_spawn",
        "snprintf",
        "strcasecmp",
        "strncasecmp",
    };
};

const Platform = enum {
    unix,
    musl,
    gnu,
    darwin,
    freebsd,
    openbsd,
    netbsd,
    mingw,
};

pub fn is(rt: *const Target, platform_libc: []const Platform) bool {
    var result = false;
    for (platform_libc) |libc| {
        if (result) return result;
        switch (libc) {
            .unix => {
                debug.assert(platform_libc.len == 1);
                return !rt.isMinGW();
            },
            .musl => result = rt.isMuslLibC(),
            .gnu => result = rt.isGnuLibC(),
            .darwin => result = rt.isDarwinLibC(),
            .freebsd => result = rt.isFreeBSDLibC(),
            .openbsd => result = rt.isOpenBSDLibC(),
            .netbsd => result = rt.isNetBSDLibC(),
            .mingw => result = rt.isMinGW(),
        }
    }
    return result;
}
