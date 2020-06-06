pub const Keypad = struct {
    const Self = @This();

    pub const Key = enum {
        One = 0x0,
        Two = 0x1,
        Three = 0x2,
        C = 0x3,
        Four = 0x4,
        Five = 0x5,
        Six = 0x6,
        D = 0x7,
        Seven = 0x8,
        Eight = 0x9,
        Nine = 0xa,
        E = 0xb,
        A = 0xc,
        Zero = 0xd,
        B = 0xe,
        F = 0xf,
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
};
