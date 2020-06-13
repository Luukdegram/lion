pub const Keypad = struct {
    const Self = @This();

    pub const Key = enum {
        Zero = 0x0,
        One = 0x1,
        Two = 0x2,
        Three = 0x3,
        Four = 0x4,
        Five = 0x5,
        Six = 0x6,
        Seven = 0x7,
        Eight = 0x8,
        Nine = 0x9,
        A = 0xA,
        B = 0xB,
        C = 0xC,
        D = 0xD,
        E = 0xE,
        F = 0xF,
    };

    keys: [16]u1 = [_]u1{0} ** 16,

    /// Sets the value of the selected key to 0x1
    pub fn pressKey(self: *Self, key: Key) void {
        self.keys[@enumToInt(key)] = 0x1;
    }

    /// Sets the value of the selected key to 0x0
    pub fn releaseKey(self: *Self, key: Key) void {
        self.keys[@enumToInt(key)] = 0x0;
    }

    /// Returns true if the given key is pressed down
    pub fn isDown(self: *Self, key: u8) bool {
        return self.keys[key] == 0x1;
    }
};
