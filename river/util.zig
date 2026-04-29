// This file is part of river, a dynamic tiling wayland compositor.
//
// Copyright 2022 The River Developers
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

/// The global general-purpose allocator used throughout river's code
pub const gpa = std.heap.c_allocator;

pub fn timestamp() std.c.timespec {
    var timespec: std.c.timespec = undefined;
    switch (std.c.errno(std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &timespec))) {
        .SUCCESS => return timespec,
        else => @panic("CLOCK_MONOTONIC not supported"),
    }
}

pub fn msecTimestamp() u32 {
    const now = timestamp();
    // 2^32-1 milliseconds is ~50 days, which is a realistic uptime.
    // This means that we must wrap if the monotonic time is greater than
    // 2^32-1 milliseconds and hope that clients don't get too confused.
    return @intCast(@rem(
        now.sec *% std.time.ms_per_s +% @divTrunc(now.nsec, std.time.ns_per_ms),
        std.math.maxInt(u32),
    ));
}
