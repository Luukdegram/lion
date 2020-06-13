const std = @import("std");
const platform = @import("platform.zig");

pub fn main() anyerror!void {
    try platform.run();
}
