// This file is part of river, a dynamic tiling wayland compositor.
//
// Copyright 2023 The River Developers
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

const XdgDecoration = @This();

const std = @import("std");
const assert = std.debug.assert;
const wlr = @import("wlroots");
const wl = @import("wayland").server.wl;

const server = &@import("main.zig").server;
const util = @import("util.zig");

const XdgToplevel = @import("XdgToplevel.zig");

wlr_decoration: *wlr.XdgToplevelDecorationV1,

destroy: wl.Listener(*wlr.XdgToplevelDecorationV1) =
    wl.Listener(*wlr.XdgToplevelDecorationV1).init(handleDestroy),
request_mode: wl.Listener(*wlr.XdgToplevelDecorationV1) =
    wl.Listener(*wlr.XdgToplevelDecorationV1).init(handleRequestMode),

pub fn init(wlr_decoration: *wlr.XdgToplevelDecorationV1) void {
    const toplevel: *XdgToplevel = @ptrCast(@alignCast(wlr_decoration.toplevel.base.data));

    toplevel.decoration = .{ .wlr_decoration = wlr_decoration };
    const decoration = &toplevel.decoration.?;

    wlr_decoration.events.destroy.add(&decoration.destroy);
    wlr_decoration.events.request_mode.add(&decoration.request_mode);

    if (toplevel.wlr_toplevel.base.initialized) {
        handleRequestMode(&decoration.request_mode, wlr_decoration);
    }
}

pub fn deinit(decoration: *XdgDecoration) void {
    const toplevel: *XdgToplevel = @ptrCast(@alignCast(decoration.wlr_decoration.toplevel.base.data));

    decoration.destroy.link.remove();
    decoration.request_mode.link.remove();

    assert(toplevel.decoration != null);
    toplevel.decoration = null;
}

fn handleDestroy(
    listener: *wl.Listener(*wlr.XdgToplevelDecorationV1),
    _: *wlr.XdgToplevelDecorationV1,
) void {
    const decoration: *XdgDecoration = @fieldParentPtr("destroy", listener);

    decoration.deinit();
}

fn handleRequestMode(
    listener: *wl.Listener(*wlr.XdgToplevelDecorationV1),
    _: *wlr.XdgToplevelDecorationV1,
) void {
    const decoration: *XdgDecoration = @fieldParentPtr("request_mode", listener);

    const toplevel: *XdgToplevel = @ptrCast(@alignCast(decoration.wlr_decoration.toplevel.base.data));
    const view = toplevel.view;

    const ssd = server.config.rules.ssd.match(toplevel.view) orelse
        (decoration.wlr_decoration.requested_mode != .client_side);

    if (view.pending.ssd != ssd) {
        view.pending.ssd = ssd;
        server.root.applyPending();
    }
}
