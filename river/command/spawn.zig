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

const std = @import("std");
const c = std.c;

const util = @import("../util.zig");
const process = @import("../process.zig");

const Error = @import("../command.zig").Error;
const Seat = @import("../Seat.zig");

/// Spawn a program.
pub fn spawn(
    _: *Seat,
    args: []const [:0]const u8,
    out: *?[]const u8,
) Error!void {
    if (args.len < 2) return Error.NotEnoughArguments;
    if (args.len > 2) return Error.TooManyArguments;

    const child_args = [_:null]?[*:0]const u8{ "/bin/sh", "-c", args[1], null };

    const pid: c.pid_t = blk: {
        const rc = c.fork();
        if (c.errno(rc) != .SUCCESS) {
            out.* = try std.fmt.allocPrint(util.gpa, "fork/execve failed", .{});
            return Error.Other;
        }
        break :blk @intCast(rc);
    };

    if (pid == 0) {
        process.cleanupChild();

        const pid2: c.pid_t = blk: {
            const rc = c.fork();
            if (c.errno(rc) != .SUCCESS) {
                c._exit(1);
            }
            break :blk @intCast(rc);
        };

        if (pid2 == 0) {
            _ = c.execve("/bin/sh", &child_args, c.environ);
            c._exit(1); // only reachable if execve fails
        }

        c._exit(0);
    }

    // Wait the intermediate child.
    const status: u32 = while (true) {
        var status: c_int = 0;
        switch (c.errno(c.waitpid(pid, &status, 0))) {
            .SUCCESS => break @bitCast(status),
            .INTR => continue,
            else => return Error.Unexpected, // should never happen, but don't trust the kernel
        }
    };

    if (!c.W.IFEXITED(status) or
        (c.W.IFEXITED(status) and c.W.EXITSTATUS(status) != 0))
    {
        out.* = try std.fmt.allocPrint(util.gpa, "fork/execve failed", .{});
        return Error.Other;
    }
}
