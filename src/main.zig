const std = @import("std");
const emulator = @import("emulator.zig");

pub fn main() anyerror!void {
    try emulator.run();
}
