const std = @import("std");

const Keypad = @import("keypad.zig").Keypad;

/// The starting address in memory space,
/// anything before this is storage and reserved memory
const start_address = 0x200;
/// Starting address of where the fonts are located in the memory
const font_start_address = 0x50;
/// Video height in pixels
const height = 32;
/// Video width in pixels
const width = 64;

/// The supported Font Set of 8Chip
pub const font_set = &[_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

/// Callback function that can be used to update the frame
/// of a display, such as a GUI or Terminal UI.
pub const UpdateFrameFn = fn ([]u1) void;

/// Cpu is the 8Chip implementation, it contains the memory,
/// opcodes and handles the cycle. Video output can be accessed
/// directly, but is not thread-safe currently.
pub const Cpu = struct {
    /// memory of the cpu, that is segmented into 3 parts:
    /// 1. 0x00-0x1FF reserved memory for interpreter
    /// 2. 0x050-0x0A0 storage space
    /// 3. 0x200-0xFFF instructors from ROM at 0x200, after that is free
    memory: [4096]u8 = [_]u8{0} ** 4096,
    /// 8-chip registry, contains V0 to VF, has calues between 0x00 to 0xFF
    registers: [16]u8,
    /// Special register to store memory addreses for use in operations
    index_register: u16,
    /// The program counter that stores which operation to run next
    pc: u16,
    /// The CPU stack that keeps track of the order of execution
    stack: [16]u16,
    /// The stack pointer keeps track of where we are in the stack
    sp: u8 = 0,
    /// Timer for delay, decrements until 0 and remains 0
    delay_timer: u8,
    /// Timer used for emitting sound, decrements to 0. Anything non-zero emits a sound
    sound_timer: u8,
    /// keypad input keys
    keypad: Keypad,
    /// The pixels to write a sprite to
    video: Video,
    /// generates random numbers for our opcode at 0xC000
    random: std.rand.DefaultPrng,

    /// The pixel buffer to write the sprites to
    pub const Video = struct {
        data: [width * height]u1,
        updateFrame: ?UpdateFrameFn,

        /// Calls the updateFrame function using its own data as frame
        fn update(self: *Video) void {
            if (self.updateFrame) |updateFrame| {
                updateFrame(self.data[0..]);
            }
        }
    };

    /// Currently the implementation allows to set the delay and sound timers
    /// By default, both are set to 0.
    pub const Config = struct {
        /// Delayer timer is decremented by 1 in each cpu cycle
        delay_timer: u8 = 0,
        /// Sound timer which is decremented by 1 in each cpu cycle
        sound_timer: u8 = 0,
    };

    /// Creates a new Cpu while setting the default fields
    /// `delay` sets the `delay_timer` field if not null, else 0.
    pub fn init(config: Config, comptime updateFn: ?UpdateFrameFn) Cpu {
        // seed for our random bytes
        const seed = @intCast(u64, std.time.milliTimestamp());
        // create our new cpu and set the program counter to 0x200
        var cpu = Cpu{
            .registers = [_]u8{0} ** 16,
            .index_register = 0,
            .pc = start_address,
            .stack = [_]u16{0} ** 16,
            .delay_timer = config.delay_timer,
            .sound_timer = config.sound_timer,
            .keypad = Keypad{},
            .video = Video{
                .data = [_]u1{0} ** width ** height,
                .updateFrame = updateFn,
            },
            .random = std.rand.DefaultPrng.init(seed),
        };

        // load the font set into cpu's memory
        for (font_set) |f, i| {
            cpu.memory[font_start_address + i] = f;
        }

        return cpu;
    }

    // Starts the CPU cycle and runs the currently loaded rom
    pub fn run(self: *Cpu) !void {
        var last_time = std.time.milliTimestamp();
        while (true) {
            // timing
            const current_time = std.time.milliTimestamp();
            const delta = current_time - last_time;

            if (delta > self.delay_timer) {
                last_time = current_time;

                try self.cycle();
                self.video.update();
            }
        }
    }

    /// Utility function that loads a ROM file's data and then loads it into the CPU's memory
    /// The memory allocated and returned by this is owned by the caller
    pub fn loadRom(self: *Cpu, allocator: *std.mem.Allocator, file_path: []const u8) ![]u8 {
        var file: std.fs.File = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const size = try file.getEndPos();

        var buffer = try allocator.alloc(u8, size);
        _ = try file.read(buffer);

        self.loadBytes(buffer);

        return buffer;
    }

    /// Loads data into the CPU's memory starting at `start_address` (0x200)
    pub fn loadBytes(self: *Cpu, data: []const u8) void {
        for (data) |b, i| {
            self.memory[start_address + i] = b;
        }
    }

    /// Returns the next opcode based on the memory's byte located at program counter
    /// and program counter + 1
    pub fn fetchOpcode(self: Cpu) u16 {
        return @shlExact(@intCast(u16, self.memory[self.pc]), 8) | self.memory[self.pc + 1];
    }

    /// Executes one cycle on the CPU
    pub fn cycle(self: *Cpu) !void {
        // get the next opcode
        const opcode = self.fetchOpcode();

        // executes the opcode on the cpu
        try self.dispatch(opcode);

        if (self.delay_timer > 0) {
            self.delay_timer -= 1;
        }

        if (self.sound_timer > 0) {
            self.sound_timer -= 1;
        }
    }

    /// Executes the given opcode
    pub fn dispatch(self: *Cpu, opcode: u16) !void {
        // increase program counter for each dispatch
        self.pc += 2;
        switch (opcode & 0xF000) {
            0x0000 => switch (opcode) {
                0x00E0 => {
                    // clear the screen
                    self.video.data = [_]u1{0} ** width ** height;
                },
                0x00EE => {
                    self.sp -= 1;
                    self.pc = self.stack[self.sp];
                },
                else => return error.UnknownOpcode,
            },
            0x1000 => self.pc = opcode & 0x0FFF,
            0x2000 => {
                self.stack[self.sp] = self.pc;
                self.sp += 1;
                self.pc = opcode & 0x0FFF;
            },
            // skip the following instructions if vx and kk are equal
            0x3000 => {
                const vx = (opcode & 0x0F00) >> 8;
                if (self.registers[vx] == @truncate(u8, opcode)) {
                    self.pc += 2;
                }
            },
            0x4000 => {
                const vx = (opcode & 0x0F00) >> 8;
                if (self.registers[vx] != @truncate(u8, opcode)) {
                    self.pc += 2;
                }
            },
            0x5000 => {
                const vx = (opcode & 0x0F00) >> 8;
                const vy = (opcode & 0x00F0) >> 4;
                if (self.registers[vx] == self.registers[vy]) {
                    self.pc += 2;
                }
            },
            0x6000 => {
                const vx = (opcode & 0x0F00) >> 8;
                self.registers[vx] = @truncate(u8, opcode);
            },
            0x7000 => {
                const vx = (opcode & 0x0F00) >> 8;
                const kk = @truncate(u8, opcode);

                _ = (@addWithOverflow(u8, self.registers[vx], kk, &self.registers[vx]));
            },
            0x8000 => {
                const x = (opcode & 0x0F00) >> 8;
                const y = @intCast(u8, (opcode & 0x00F0) >> 4);

                switch (opcode & 0x000F) {
                    0x0000 => self.registers[x] = self.registers[y],
                    0x0001 => self.registers[x] |= self.registers[y],
                    0x0002 => self.registers[x] &= self.registers[y],
                    0x0003 => self.registers[x] ^= self.registers[y],
                    0x0004 => {
                        var sum: u8 = undefined;
                        if (@addWithOverflow(u8, self.registers[x], self.registers[y], &sum)) {
                            self.registers[0xF] = 1;
                        } else {
                            self.registers[0xF] = 0;
                        }
                        self.registers[x] = sum;
                    },
                    0x0005 => {
                        var sub: u8 = undefined;
                        if (@subWithOverflow(u8, self.registers[x], self.registers[y], &sub)) {
                            self.registers[0xF] = 0;
                        } else {
                            self.registers[0xF] = 1;
                        }
                        self.registers[x] = sub;
                    },
                    0x0006 => {
                        self.registers[0xF] = self.registers[x] & 0x1;
                        self.registers[x] >>= 1;
                    },
                    0x0007 => {
                        var sub: u8 = undefined;
                        if (@subWithOverflow(u8, self.registers[y], self.registers[x], &sub)) {
                            self.registers[0xF] = 0;
                        } else {
                            self.registers[0xF] = 1;
                        }
                        self.registers[x] = sub;
                    },
                    0x000E => {
                        self.registers[0xF] = (self.registers[x] & 0x80) >> 7;
                        self.registers[x] <<= 1;
                    },
                    else => return error.UnknownOpcode,
                }
            },
            0x9000 => {
                const vx = (opcode & 0x0F00) >> 8;
                const vy = (opcode & 0x00F0) >> 4;
                if (self.registers[vx] != self.registers[vy]) {
                    self.pc += 2;
                }
            },
            // Set I = nnn
            0xA000 => self.index_register = opcode & 0x0FFF,
            // Jump to location nnn + V0
            0xB000 => self.pc = self.registers[0] + (opcode & 0x0FFF),
            // set Vx to random byte AND kk
            0xC000 => {
                const vx = (opcode & 0x0F00) >> 8;
                self.registers[vx] = self.random.random.int(u8) & @truncate(u8, opcode);
            },
            0xD000 => {
                // Display n-byte sprite starting at memory location I at (Vx, Vy),
                // set VF to 1 if sprite and pixel are on

                // Apply wrapping if going beyond screen boundaries
                const x = self.registers[(opcode & 0x0F00) >> 8];
                const y = self.registers[(opcode & 0x00F0) >> 4];
                const n = opcode & 0x000F;

                self.registers[0xF] = 0x0;
                var row: usize = 0;
                while (row < n) : (row += 1) {
                    const sprite_byte: u8 = self.memory[self.index_register + row];

                    var col: u8 = 0;
                    while (col < 8) : (col += 1) {
                        const sprite_pixel = sprite_byte >> @intCast(u3, (7 - col)) & 0x01;
                        var screen_pixel = &self.video.data[((y + row) % height) * width + ((x + col) % width)];

                        // Sprite pixel is on
                        if (sprite_pixel == 0x1) {
                            // screen pixel is also on
                            if (screen_pixel.* == 0x1) {
                                self.registers[0xF] = 0x1;
                            }
                            screen_pixel.* ^= 0x1;
                        }
                    }
                }
            },
            // keypad opcodes
            0xE000 => {
                const x = (opcode & 0x0F00) >> 8;
                const key = self.registers[x];

                switch (opcode & 0x00FF) {
                    0x9E => {
                        if (self.keypad.isDown(key)) {
                            self.pc += 2;
                        }
                    },
                    0xA1 => {
                        if (!self.keypad.isDown(key)) {
                            self.pc += 2;
                        }
                    },
                    else => return error.UnknownOpcode,
                }
            },
            0xF000 => {
                const x = (opcode & 0x0F00) >> 8;
                switch (opcode & 0x00FF) {
                    0x07 => self.registers[x] = self.delay_timer,
                    0x0A => {
                        self.pc -= 2;
                        for (self.keypad.keys) |k, i| {
                            if (k == 0x1) {
                                self.registers[x] = @intCast(u8, i);
                                self.pc += 2;
                            }
                        }
                    },
                    0x15 => self.delay_timer = self.registers[x],
                    0x18 => self.sound_timer = self.registers[x],
                    0x1E => self.index_register += self.registers[x],
                    0x29 => self.index_register = self.registers[x] * 5,
                    0x33 => {
                        self.memory[self.index_register] = self.registers[x] / 100;
                        self.memory[self.index_register + 1] = (self.registers[x] / 10) % 10;
                        self.memory[self.index_register + 2] = (self.registers[x] % 100) % 10;
                    },
                    0x55 => {
                        // Copy registry data into memory
                        std.mem.copy(
                            u8,
                            self.memory[self.index_register .. self.index_register + x + 1],
                            self.registers[0 .. x + 1],
                        );
                    },
                    0x65 => {
                        // Copy memory data into registry
                        std.mem.copy(
                            u8,
                            self.registers[0 .. x + 1],
                            self.memory[self.index_register .. self.index_register + x + 1],
                        );
                    },
                    else => {
                        return error.UnknownOpcode;
                    },
                }
            },
            else => return error.UnknownOpcode,
        }
    }
};
