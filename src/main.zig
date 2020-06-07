const std = @import("std");
const window = @import("window.zig");
const chip8 = @import("cpu.zig");

const test_rom = @embedFile("../roms/BC_test.ch8");

pub fn main() anyerror!void {
    std.debug.warn("All your codebase are belong to us.\n", .{});

    try window.init(.{
        .width = 800,
        .height = 600,
        .title = "Lion",
    });

    var cpu = chip8.Cpu.init(.{}, window.update);
    cpu.loadBytes(test_rom);
    try cpu.run();
}
