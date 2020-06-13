const std = @import("std");
const platform = @import("platform.zig");

pub fn main() anyerror!void {
    std.debug.warn("All your codebase are belong to us.\n", .{});

    try platform.run();
}
