const std = @import("std");
const display = @import("display.zig");

fn getTexture() [][][3]u8 {
    var tex: [][][3]u8 = undefined;
    tex[0][0][0] = 0;

    return tex;
}

pub fn main() anyerror!void {
    std.debug.warn("All your codebase are belong to us.\n", .{});

    try display.init(.{
        .width = 800,
        .height = 600,
        .title = "Lion",
    }, getTexture);
}
