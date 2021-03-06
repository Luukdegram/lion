const std = @import("std");
const warn = std.debug.warn;
const window = @import("window.zig");
const chip8 = @import("cpu.zig");
const c = @import("c.zig");
const Key = @import("keypad.zig").Keypad.Key;
const Thread = @import("std").Thread;
const audio = @import("audio.zig");

const test_rom = @embedFile("../assets/roms/test_opcode.ch8");

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
        c.GLFW_KEY_R => {
            if (action == c.GLFW_PRESS) {
                cpu.reset();
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
                audio.muteOrUnmute();
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
    var allocator = std.heap.page_allocator;
    const file_path = parseArgumentsToFilePath(allocator) catch {
        warn("Missing filepath argument for ROM\n", .{});
        return;
    };
    defer allocator.free(file_path);

    audio.init("assets/sound/8bitgame10.wav", 1024 * 100) catch {
        warn("Could not open the audio file, continuing without sound\n", .{});
    };

    defer audio.deinit();

    try window.init(.{
        .width = 1200,
        .height = 600,
        .title = "Lion",
    }, keyCallback);

    defer window.deinit();

    cpu = chip8.Cpu.init(.{
        .audio_callback = audio.play,
        .sound_timer = 1,
        .video_callback = window.update,
    });
    var rom_bytes = try cpu.loadRom(allocator, file_path);
    defer allocator.free(rom_bytes);

    cpu_context = CpuContext{ .cpu = &cpu };
    _ = try Thread.spawn(cpu_context, startCpu);

    window.run();
}

/// Starts the cpu on a different thread
fn startCpu(context: CpuContext) void {
    context.cpu.run() catch |err| {
        warn("Error occured while running the cpu: {}\n", .{err});
    };
}

// parses the given arguments to the executable,
// returns MissingArgument if no argument is given for the ROM file path.
fn parseArgumentsToFilePath(allocator: *std.mem.Allocator) ![]const u8 {
    var args = std.process.args();
    // skip first argument
    const exe = try args.next(allocator) orelse unreachable;
    allocator.free(exe);

    return args.next(allocator) orelse return error.MissingArgument;
}
