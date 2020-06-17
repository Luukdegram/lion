const emulator = @import("emulator.zig");

pub fn main() !void {
    try emulator.run();
}
