const std = @import("std");

const start_address = 0x200;
const font_start_address = 0x50;
const height = 32;
const width = 64;

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

pub const Cpu = struct {
    /// memory of the cpu, that is segmented into 3 parts:
    /// 1. 0x00-0x1FF reserved memory for interpreter
    /// 2. 0x050-0x0A0 storage space
    /// 3. 0x200-0xFFF instructors from ROM at 0x200, after that is free
    memory: [4096]u8 = [_]u8{0} ** 4096,
    /// 8-chip registry, contains V0 to VF, has calues between 0x00 to 0xFF
    registers: [16]u8 = [_]u8{0} ** 16,
    /// Special register to store memory addreses for use in operations
    index_register: u16 = 0,
    /// The program counter that stores which operation to run next
    pc: u16,
    /// The CPU stack that keeps track of the order of execution
    stack: [16]u16 = [_]u16{0} ** 16,
    /// The stack pointer keeps track of where we are in the stack
    sp: u8 = 0,
    /// Timer for delay, decrements until 0 and remains 0
    delay_timer: u8 = 0,
    /// Timer used for emissing sound, decrements to 0. Anything non-zero emits a sound
    sound_timer: u8 = 0,
    /// keypad input keys
    input_keys: [16]u8 = [_]u8{0} ** 16,
    /// The pixels to write a sprite to
    video: [width * height]u8 = [_]u8{0} ** width ** height,
    /// generates random numbers for our opcode at 0xC000
    random: std.rand.DefaultPrng,

    pub fn init() Cpu {
        // seed for our random bytes
        const seed = @intCast(u64, std.time.milliTimestamp());
        // create our new cpu and set the program counter to 0x200
        var cpu = Cpu{
            .pc = start_address,
            .random = std.rand.DefaultPrng.init(seed),
        };

        // load the font set into cpu's memory
        for (font_set) |f, i| {
            cpu.memory[font_start_address + i] = f;
        }

        return cpu;
    }

    /// Loads a ROM file into the cpu's memory
    pub fn loadRom(self: *Cpu, file_path: []const u8) !void {
        var file: std.fs.File = try std.fs.cwd().openFile(file_path, .{});

        const size = try file.getEndPos();

        // since we know the max size of the 8-Chip's memory, there's no need for an allocator
        var buffer: [4096]u8 = undefined;
        _ = try file.read(buffer);

        var i: usize = 0;
        while (i < size) : (i += 1) {
            self.memory[i] = buffer[i];
        }
    }

    /// Executes the given opcode on the cpu
    pub fn dispatchOp(self: *Cpu, opcode: u16) !void {
        switch (opcode & 0xF000) {
            0x0000 => switch (opcode) {
                0x00E0 => {
                    // clear the screen
                    self.video = .{0} * width * height;
                    self.pc += 2;
                },
                0x00EE => {
                    self.pc = self.stack[self.sp];
                    self.sp -= 1;
                    self.pc += 2;
                },
                else => return error.UnknownOpcode,
            },
            0x1000 => self.pc = opcode & 0x0FFF,
            0x2000 => {
                self.stack[self.sp] = self.pc;
                self.sp -= 1;
                self.pc = opcode & 0x0FFF;
            },
            // skip the following instructions if vx and kk are equal
            0x3000, 0x4000 => {
                const vx = (opcode & 0x0F00) >> 8;
                const kk = opcode & 0x00FF;
                if (self.registers[vx] == kk) {
                    self.pc += 2;
                }
            },
            0x5000 => {
                const vx = (opcode & 0x0F00) >> 8;
                const vy = (opcode & 0x0F00) >> 4;
                if (self.registers[vx] == vy) {
                    pc += 2;
                }
            },
            0x6000 => {
                const vx = (opcode & 0x0F00) >> 8;
                const kk = opcode & 0x00FF;
                self.registers[vx] = kk;
            },
            0x7000 => {
                const vx = (opcode & 0x0F00) >> 8;
                const kk = opcode & 0x00FF;
                self.registers[vx] += kk;
            },
            0x8000 => {
                const x = (opcode & 0x0F00) >> 8;
                const y = (opcode & 0x0F00) >> 4;

                switch (opcode & 0x000F) {
                    0x0000 => self.registers[x] = y,
                    0x0001 => self.registers[x] |= y,
                    0x0002 => self.registers[x] &= y,
                    0x0003 => self.registers[x] ^= y,
                    0x0004 => {
                        const sum = self.registers[x] + self.registers[y];
                        self.registers[0xF] = if (sum > 255) 1 else 0;
                        self.registers[x] = @truncate(u8, sum);
                    },
                    0x0005 => {
                        self.registers[0xF] = if (self.registers[x] > self.registers[y]) 1 else 0;
                        self.registers[x] -= self.registers[y];
                    },
                    0x0006 => {
                        self.registers[0xF] = (self.registers[x] & 0x1);
                        self.registers[x] >>= 1;
                    },
                    0x0007 => {
                        self.registers[0xF] = if (self.registers[y] > self.registers[x]) 1 else 0;
                        self.registers[x] = self.registers[y] - self.registers[x];
                    },
                    0x000E => {
                        self.registers[0xF] = (self.registers[x] & 0x80) >> 7;
                        self.registers[x] <<= 1;
                    },
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
                const kk = opcode & 0x00FF;
                self.registers[vx] = self.random.random.int(u8) & kk;
            },
            // Dxyn - DRW Vx, Vy, nibble
            0xD000 => {
                // Display n-byte sprite starting at memory location I at (Vx, Vy),
                // set VF = collision

                //TODO Finish this opcode

                // Apply wrapping if going beyond screen boundaries
                const x = self.registers[(opcode & 0x0F00) >> 8] % width;
                const y = self.registers[(opcode & 0x00FF) >> 4] % height;
                const height = opcode & 0x000F;

                self.registers[0xF] = 0;
                var row: usize = 0;
                var col: usize = 0;
                while (row < height) : (row += 1) {
                    const sprite_byte = self.memory[self.index_register + row];

                    while (col < 8) : (col += 1) {
                        const sprite_pixel: u8 = sprite_byte & (0x80 >> col);
                        var screen_pixel = &self.video[(y + row) * width + (x + col)];

                        // Sprite pixel is on
                        if (sprite_pixel == 1) {}
                    }
                }
            },
            // keypad opcodes

            0xE000 => {
                const x = (opcode & 0x0F00) >> 8;
                switch (opcode & 0x00FF) {
                    0x9E => {
                        
                    },
                    0xA1 => {},
                }
            },
        }
    }
};

test "init CPU" {
    var cpu = Cpu.init();
}
