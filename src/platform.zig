const warn = @import("std").debug.warn;
const window = @import("window.zig");
const chip8 = @import("cpu.zig");
const c = @import("c.zig");
const Key = @import("keypad.zig").Keypad.Key;
const Thread = @import("std").Thread;

const test_rom = @embedFile("../roms/test_opcode.ch8");

var cpu: chip8.Cpu = undefined;

/// CpuContext is the context running on a different thread
const CpuContext = struct {
    cpu: *chip8.Cpu
};

var cpu_context: CpuContext = undefined;

/// GLFW key input callback
fn keyCallback(win: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    switch (key) {
        c.GLFW_KEY_ESCAPE => {
            if (action == c.GLFW_PRESS) {
                cpu.stop();
                window.shutdown();
            }
        },
        c.GLFW_KEY_P => {
            if (action == c.GLFW_PRESS) {
                if (cpu.running()) {
                    cpu.stop();
                } else {
                    _ = Thread.spawn(cpu_context, startCpu) catch {
                        warn("Could not start the CPU. Exiting...\n", .{});
                        window.shutdown();
                    };
                }
            }
        },
        c.GLFW_KEY_A => pressKeypad(action, Key.A),
        c.GLFW_KEY_B => pressKeypad(action, Key.B),
        c.GLFW_KEY_C => pressKeypad(action, Key.C),
        c.GLFW_KEY_D => pressKeypad(action, Key.D),
        c.GLFW_KEY_E => pressKeypad(action, Key.E),
        c.GLFW_KEY_F => pressKeypad(action, Key.F),
        c.GLFW_KEY_1 => pressKeypad(action, Key.One),
        c.GLFW_KEY_2 => pressKeypad(action, Key.Two),
        c.GLFW_KEY_3 => pressKeypad(action, Key.Three),
        c.GLFW_KEY_4 => pressKeypad(action, Key.Four),
        c.GLFW_KEY_5 => pressKeypad(action, Key.Five),
        c.GLFW_KEY_6 => pressKeypad(action, Key.Six),
        c.GLFW_KEY_7 => pressKeypad(action, Key.Seven),
        c.GLFW_KEY_8 => pressKeypad(action, Key.Eight),
        c.GLFW_KEY_9 => pressKeypad(action, Key.Nine),
        c.GLFW_KEY_0 => pressKeypad(action, Key.Zero),
        c.GLFW_KEY_M => {
            if (action == c.GLFW_PRESS) {
                @import("std").debug.warn("Implement Mute after we implement sound\n", .{});
            }
        },
        else => {},
    }
}

/// helper function to call the right keypad function based on the action
fn pressKeypad(action: c_int, key: Key) void {
    if (action == c.GLFW_PRESS) {
        cpu.keypad.pressKey(key);
    } else {
        cpu.keypad.releaseKey(key);
    }
}

/// Starts up the program
pub fn run() !void {
    try window.init(.{
        .width = 1200,
        .height = 600,
        .title = "Lion",
    }, keyCallback);

    defer window.deinit();

    cpu = chip8.Cpu.init(.{}, window.update);
    cpu.loadBytes(test_rom);

    cpu_context = CpuContext{ .cpu = &cpu };
    _ = try Thread.spawn(cpu_context, startCpu);

    window.run();
}

/// Starts the cpu on a different thread
fn startCpu(context: CpuContext) void {
    context.cpu.run() catch |err| {
        warn("Error occured when running the cpu: {}\n", .{err});
    };
}
