//
// Copyright © 2022 Collabora Inc.
//
// SPDX-License-Identifier: LGPL-2.1-or-later
//
// Original author: Xavier Claessens <xclaesse@gmail.com>
// Zig port: converted from Python

const std = @import("std");
const process = std.process;
const mem = std.mem;
const meta = std.meta;

const Dir = std.Io.Dir;

const SubCommand = enum {
    @"visibility-macros",
    @"versions-macros",
};

const Namespace = enum {
    GLIB,
    GOBJECT,
    GIO,
    GMODULE,
    GI,
};

const usage =
    \\Usage: gen-visibility-macros <glib_version 2.26..> <subcommand> [args...]
    \\
    \\Subcommands:
    \\  visibility-macros <namespace> <out_path>
    \\  versions-macros <in_path> <out_path>
    \\
    \\Namespaces:
    \\  GLIB
    \\  GOBJECT
    \\  GIO
    \\  GMODULE
    \\  GI
    \\
;

pub fn main(init: process.Init) !void {
    var gpa = init.gpa;
    const args = try init.minimal.args.toSlice(gpa);
    defer gpa.free(args);
    const io = init.io;

    if (args.len < 5) {
        std.debug.print(usage, .{});
        process.exit(1);
    }

    const glib_version_str = args[1];
    const subcommand_str = args[2];

    // Parse version: expect "2.X.Y"
    var glib_version = std.SemanticVersion.parse(glib_version_str) catch unreachable;
    const major_version = glib_version.major;
    const minor_version = glib_version.minor;
    std.debug.assert(major_version == 2);
    std.debug.assert(minor_version >= 26);

    const subcommand = meta.stringToEnum(SubCommand, subcommand_str) orelse return error.InvalidSubCommand;

    switch (subcommand) {
        .@"visibility-macros" => {
            const namespace = meta.stringToEnum(Namespace, args[3]) orelse return error.InvalidNamespace;
            try genVisibilityMacros(io, namespace, args[4], minor_version);
        },
        .@"versions-macros" => {
            try genVersionsMacros(io, gpa, args[3], args[4], minor_version);
        },
    }
}

fn genVersionsMacros(
    io: std.Io,
    gpa: mem.Allocator,
    in_path: []const u8,
    out_path: []const u8,
    current_minor_version: usize,
) !void {
    const in_file = try Dir.cwd().openFile(io, in_path, .{});
    const stat = try in_file.stat(io);
    const buffer = try gpa.alloc(u8, stat.size);
    defer gpa.free(buffer);

    _ = try in_file.readPositionalAll(io, buffer, 0);

    const out_file = try Dir.cwd().createFile(io, out_path, .{});
    defer out_file.close(io);

    var writer = out_file.writer(io, &.{});
    const w = &writer.interface;

    var line_iter = mem.splitAny(u8, buffer, "\n\t");
    while (line_iter.next()) |line| {
        // Re-add the newline (splitScalar strips it); skip adding for the very
        // last empty slice
        const is_last = line_iter.peek() == null;

        if (mem.indexOf(u8, line, "@GLIB_VERSIONS@") != null) {
            var minor: u32 = 2;
            while (minor <= current_minor_version + 2) : (minor += 2) {
                const since = @max(minor, 32);
                try w.print(
                    \\/**
                    \\ * GLIB_VERSION_2_{[minor]d}:
                    \\ *
                    \\ * A macro that evaluates to the 2.{[minor]d} version of GLib, in a format
                    \\ * that can be used by the C pre-processor.
                    \\ *
                    \\ * Since: 2.{[since]d}
                    \\ */
                    \\#define GLIB_VERSION_2_{[minor]d}       (G_ENCODE_VERSION (2, {[minor]d}))
                    \\
                , .{ .minor = minor, .since = since });
            }
        } else {
            try w.writeAll(line);
            if (!is_last) try w.writeByte('\n');
        }
    }
}

fn genVisibilityMacros(
    io: std.Io,
    namespace: Namespace,
    out_path: []const u8,
    current_minor_version: usize,
) !void {
    const out_file = try Dir.cwd().createFile(io, out_path, .{});
    defer out_file.close(io);

    var writer = out_file.writer(io, &.{});
    const w = &writer.interface;

    // Write the header preamble
    try w.print(
        \\#pragma once
        \\
        \\#if (defined(_WIN32) || defined(__CYGWIN__)) && !defined({[ns]t}_STATIC_COMPILATION)
        \\#  define _{[ns]t}_EXPORT __declspec(dllexport)
        \\#  define _{[ns]t}_IMPORT __declspec(dllimport)
        \\#elif __GNUC__ >= 4
        \\#  define _{[ns]t}_EXPORT __attribute__((visibility("default")))
        \\#  define _{[ns]t}_IMPORT
        \\#else
        \\#  define _{[ns]t}_EXPORT
        \\#  define _{[ns]t}_IMPORT
        \\#endif
        \\#ifdef {[ns]t}_COMPILATION
        \\#  define _{[ns]t}_API _{[ns]t}_EXPORT
        \\#else
        \\#  define _{[ns]t}_API _{[ns]t}_IMPORT
        \\#endif
        \\
        \\#define _{[ns]t}_EXTERN _{[ns]t}_API extern
        \\
        \\#define {[ns]t}_VAR _{[ns]t}_EXTERN
        \\#define {[ns]t}_AVAILABLE_IN_ALL _{[ns]t}_EXTERN
        \\
        \\#ifdef GLIB_DISABLE_DEPRECATION_WARNINGS
        \\#define {[ns]t}_DEPRECATED _{[ns]t}_EXTERN
        \\#define {[ns]t}_DEPRECATED_FOR(f) _{[ns]t}_EXTERN
        \\#define {[ns]t}_UNAVAILABLE(maj,min) _{[ns]t}_EXTERN
        \\#define {[ns]t}_UNAVAILABLE_STATIC_INLINE(maj,min)
        \\#else
        \\#define {[ns]t}_DEPRECATED G_DEPRECATED _{[ns]t}_EXTERN
        \\#define {[ns]t}_DEPRECATED_FOR(f) G_DEPRECATED_FOR(f) _{[ns]t}_EXTERN
        \\#define {[ns]t}_UNAVAILABLE(maj,min) G_UNAVAILABLE(maj,min) _{[ns]t}_EXTERN
        \\#define {[ns]t}_UNAVAILABLE_STATIC_INLINE(maj,min) G_UNAVAILABLE(maj,min)
        \\#endif
        \\
    , .{ .ns = namespace });

    // Write per-version macros starting from 2.26
    var minor: u32 = 26;
    while (minor <= current_minor_version + 2) : (minor += 2) {
        try w.print(
            \\
            \\#if GLIB_VERSION_MIN_REQUIRED >= GLIB_VERSION_2_{[minor]d}
            \\#define {[ns]t}_DEPRECATED_IN_2_{[minor]d} {[ns]t}_DEPRECATED
            \\#define {[ns]t}_DEPRECATED_IN_2_{[minor]d}_FOR(f) {[ns]t}_DEPRECATED_FOR (f)
            \\#define {[ns]t}_DEPRECATED_MACRO_IN_2_{[minor]d} GLIB_DEPRECATED_MACRO
            \\#define {[ns]t}_DEPRECATED_MACRO_IN_2_{[minor]d}_FOR(f) GLIB_DEPRECATED_MACRO_FOR (f)
            \\#define {[ns]t}_DEPRECATED_ENUMERATOR_IN_2_{[minor]d} GLIB_DEPRECATED_ENUMERATOR
            \\#define {[ns]t}_DEPRECATED_ENUMERATOR_IN_2_{[minor]d}_FOR(f) GLIB_DEPRECATED_ENUMERATOR_FOR (f)
            \\#define {[ns]t}_DEPRECATED_TYPE_IN_2_{[minor]d} GLIB_DEPRECATED_TYPE
            \\#define {[ns]t}_DEPRECATED_TYPE_IN_2_{[minor]d}_FOR(f) GLIB_DEPRECATED_TYPE_FOR (f)
            \\#else
            \\#define {[ns]t}_DEPRECATED_IN_2_{[minor]d} _{[ns]t}_EXTERN
            \\#define {[ns]t}_DEPRECATED_IN_2_{[minor]d}_FOR(f) _{[ns]t}_EXTERN
            \\#define {[ns]t}_DEPRECATED_MACRO_IN_2_{[minor]d}
            \\#define {[ns]t}_DEPRECATED_MACRO_IN_2_{[minor]d}_FOR(f)
            \\#define {[ns]t}_DEPRECATED_ENUMERATOR_IN_2_{[minor]d}
            \\#define {[ns]t}_DEPRECATED_ENUMERATOR_IN_2_{[minor]d}_FOR(f)
            \\#define {[ns]t}_DEPRECATED_TYPE_IN_2_{[minor]d}
            \\#define {[ns]t}_DEPRECATED_TYPE_IN_2_{[minor]d}_FOR(f)
            \\#endif
            \\
            \\#if GLIB_VERSION_MAX_ALLOWED < GLIB_VERSION_2_{[minor]d}
            \\#define {[ns]t}_AVAILABLE_IN_2_{[minor]d} {[ns]t}_UNAVAILABLE (2, {[minor]d})
            \\#define {[ns]t}_AVAILABLE_STATIC_INLINE_IN_2_{[minor]d} GLIB_UNAVAILABLE_STATIC_INLINE (2, {[minor]d})
            \\#define {[ns]t}_AVAILABLE_MACRO_IN_2_{[minor]d} GLIB_UNAVAILABLE_MACRO (2, {[minor]d})
            \\#define {[ns]t}_AVAILABLE_ENUMERATOR_IN_2_{[minor]d} GLIB_UNAVAILABLE_ENUMERATOR (2, {[minor]d})
            \\#define {[ns]t}_AVAILABLE_TYPE_IN_2_{[minor]d} GLIB_UNAVAILABLE_TYPE (2, {[minor]d})
            \\#else
            \\#define {[ns]t}_AVAILABLE_IN_2_{[minor]d} _{[ns]t}_EXTERN
            \\#define {[ns]t}_AVAILABLE_STATIC_INLINE_IN_2_{[minor]d}
            \\#define {[ns]t}_AVAILABLE_MACRO_IN_2_{[minor]d}
            \\#define {[ns]t}_AVAILABLE_ENUMERATOR_IN_2_{[minor]d}
            \\#define {[ns]t}_AVAILABLE_TYPE_IN_2_{[minor]d}
            \\#endif
            \\
        , .{ .ns = namespace, .minor = minor });
    }
}
