const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();
    if (!args.skip()) @panic("no argv0");
    const prefix = args.next() orelse @panic("no prefix");
    const version = args.next() orelse @panic("no version");
    if (args.skip()) @panic("too many arguments");

    const stdout = std.Io.File.stdout();
    defer stdout.close(init.io);
    var out_buf: [1024]u8 = undefined;
    var out = stdout.writer(init.io, &out_buf);
    try out.interface.print(
        \\prefix={s}
        \\datadir=${{prefix}}/share
        \\pkgdatadir=${{datadir}}/river-protocols
        \\
        \\Name: river-protocols
        \\URL: https://codeberg.org/river/river
        \\Description: protocol files for the river wayland compositor
        \\Version: {s}
        , .{prefix, version});
    try out.flush();
}
