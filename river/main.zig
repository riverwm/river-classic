// This file is part of river, a dynamic tiling wayland compositor.
//
// Copyright 2020 The River Developers
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

const build_options = @import("build_options");
const std = @import("std");
const Io = std.Io;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const posix = std.posix;
const exit = std.process.exit;
const fatal = std.process.fatal;
const c = std.c;

const builtin = @import("builtin");
const wlr = @import("wlroots");
const flags = @import("flags");

const util = @import("util.zig");
const process = @import("process.zig");

const Server = @import("Server.zig");

const usage: []const u8 =
    \\usage: river [options]
    \\
    \\  -h                 Print this help message and exit.
    \\  -version           Print the version number and exit.
    \\  -c <command>       Run `sh -c <command>` on startup instead of the default init executable.
    \\  -log-level <level> Set the log level to error, warning, info, or debug.
    \\  -no-xwayland       Disable xwayland even if built with support.
    \\
;

pub var server: Server = undefined;

pub fn main(init: std.process.Init.Minimal) anyerror!void {
    const io = std.Io.Threaded.global_single_threaded.io();

    var stdout_buffer: [64]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var stderr_buffer: [64]u8 = undefined;
    var stderr_writer = Io.File.stderr().writer(io, &stderr_buffer);
    const stderr = &stderr_writer.interface;

    const args = try init.args.toSlice(util.gpa);
    defer util.gpa.free(args);

    const result = flags.parser(&.{
        .{ .name = "h", .kind = .boolean },
        .{ .name = "version", .kind = .boolean },
        .{ .name = "c", .kind = .arg },
        .{ .name = "log-level", .kind = .arg },
        .{ .name = "no-xwayland", .kind = .boolean },
    }).parse(args[1..]) catch {
        try stderr.writeAll(usage);
        try stderr.flush();
        exit(1);
    };
    if (result.flags.h) {
        try stdout.writeAll(usage);
        try stdout.flush();
        exit(0);
    }
    if (result.args.len != 0) {
        log.err("unknown option '{s}'", .{result.args[0]});
        try stderr.writeAll(usage);
        try stderr.flush();
        exit(1);
    }

    if (result.flags.version) {
        try stdout.writeAll(build_options.version ++ "\n");
        try stdout.flush();
        exit(0);
    }
    if (result.flags.@"log-level") |level| {
        if (mem.eql(u8, level, "error")) {
            runtime_log_level = .err;
        } else if (mem.eql(u8, level, "warning")) {
            runtime_log_level = .warn;
        } else if (mem.eql(u8, level, "info")) {
            runtime_log_level = .info;
        } else if (mem.eql(u8, level, "debug")) {
            runtime_log_level = .debug;
        } else {
            log.err("invalid log level '{s}'", .{level});
            try stderr.writeAll(usage);
            try stderr.flush();
            exit(1);
        }
    }
    const runtime_xwayland = !result.flags.@"no-xwayland";
    const startup_command = blk: {
        if (result.flags.c) |command| {
            break :blk try util.gpa.dupeZ(u8, command);
        } else {
            break :blk try defaultInitPath(io, init.environ);
        }
    };

    log.info("river version {s}, initializing server", .{build_options.version});

    river_init_wlroots_log(switch (runtime_log_level) {
        .debug => .debug,
        .info => .info,
        .warn, .err => .err,
    });

    try server.init(runtime_xwayland);
    defer server.deinit();

    // wlroots starts the Xwayland process from an idle event source, the reasoning being that
    // this gives the compositor time to set up event listeners before Xwayland is actually
    // started. We want Xwayland to be started by wlroots before we modify our rlimits in
    // process.setup() since wlroots does not offer a way for us to reset the rlimit post-fork.
    if (build_options.xwayland and runtime_xwayland) {
        server.wl_server.getEventLoop().dispatchIdle();
    }

    process.setup();

    try server.start();

    // Run the child in a new process group so that we can send SIGTERM to all
    // descendants on exit.
    const child_pgid = if (startup_command) |cmd| blk: {
        log.info("running init executable '{s}'", .{cmd});
        const child_args = [_:null]?[*:0]const u8{ "/bin/sh", "-c", cmd, null };

        const pid: c.pid_t = pid: {
            const rc = c.fork();
            switch (c.errno(rc)) {
                .SUCCESS => {},
                else => |err| fatal("failed to start init process: {}", .{err}),
            }
            break :pid @intCast(rc);
        };

        if (pid == 0) {
            process.cleanupChild();
            _ = c.execve("/bin/sh", &child_args, c.environ);
            c._exit(1); // only reachable if execve fails
        }
        util.gpa.free(cmd);
        // Since the child has called setsid, the pid is the pgid
        break :blk pid;
    } else null;
    defer if (child_pgid) |pgid| posix.kill(-pgid, posix.SIG.TERM) catch |err| {
        log.err("failed to kill init process group: {s}", .{@errorName(err)});
    };

    log.info("running server", .{});

    server.wl_server.run();

    log.info("shutting down", .{});
}

fn defaultInitPath(io: Io, environ: std.process.Environ) !?[:0]const u8 {
    const path = blk: {
        if (environ.getPosix("XDG_CONFIG_HOME")) |xdg_config_home| {
            break :blk try fs.path.joinZ(util.gpa, &[_][]const u8{ xdg_config_home, "river/init" });
        } else if (environ.getPosix("HOME")) |home| {
            break :blk try fs.path.joinZ(util.gpa, &[_][]const u8{ home, ".config/river/init" });
        } else {
            return null;
        }
    };

    Io.Dir.cwd().access(io, path, .{ .execute = true }) catch |err| {
        if (err == error.PermissionDenied) {
            if (Io.Dir.cwd().access(io, path, .{})) {
                fatal("failed to run init executable {s}: the file is not executable", .{path});
            } else |_| {}
        }
        log.err("failed to run init executable {s}: {s}", .{ path, @errorName(err) });
        util.gpa.free(path);
        return null;
    };

    return path;
}

/// Set the default log level based on the build mode.
var runtime_log_level: log.Level = switch (builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe, .ReleaseFast, .ReleaseSmall => .info,
};

pub const std_options: std.Options = .{
    // Tell std.log to leave all log level filtering to us.
    .log_level = .debug,
    .logFn = logFn,
};

pub fn logFn(
    comptime level: log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(level) > @intFromEnum(runtime_log_level)) return;

    std.log.defaultLog(level, scope, format, args);
}

/// See wlroots_log_wrapper.c
extern fn river_init_wlroots_log(importance: wlr.log.Importance) void;
export fn river_wlroots_log_callback(importance: wlr.log.Importance, ptr: [*:0]const u8, len: usize) void {
    const wlr_log = log.scoped(.wlroots);
    switch (importance) {
        .err => wlr_log.err("{s}", .{ptr[0..len]}),
        .info => wlr_log.info("{s}", .{ptr[0..len]}),
        .debug => wlr_log.debug("{s}", .{ptr[0..len]}),
        .silent, .last => unreachable,
    }
}
