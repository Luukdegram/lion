const Cpu = @import("cpu.zig").Cpu;
const Keypad = @import("keypad.zig").Keypad;

usingnamespace @import("std").testing;

test "Next opcode" {
    var cpu = Cpu.init(.{});

    cpu.memory[0x200] = 0xA2;
    cpu.memory[0x201] = 0xF0;

    expect(cpu.fetchOpcode() == 0xA2F0);
}

test "Load data" {
    var cpu = Cpu.init(.{});
    const data = [_]u8{ 0x01, 0x02 };
    cpu.loadBytes(&data);

    expect(cpu.fetchOpcode() == 0x0102);
    expect(cpu.memory[0x200] == 0x01);
    expect(cpu.memory[0x200 + 1] == 0x02);
}

test "Cycle" {
    var cpu = Cpu.init(.{});
    const data = [_]u8{ 0xA1, 0x00 };
    cpu.loadBytes(&data);

    const opcode = cpu.fetchOpcode();
    try cpu.cycle();

    // program counter moves 2 per cycle (except for some opcode conditions where it skips)
    expect(cpu.pc == 0x202);
    expect(opcode == 0xA100);
}

test "Expect Unknown Opcode" {
    var cpu = Cpu.init(.{});
    expectError(error.UnknownOpcode, cpu.dispatch(0x1));
}

test "Key (un)pressed" {
    var keypad = Keypad{};
    keypad.pressKey(.Two);
    expect(keypad.keys[0x1] == 0x1);
    keypad.releaseKey(.Two);
    expect(keypad.keys[0x1] == 0x0);
}

test "All opcodes" {
    // Not the cleanest tests but gets the job done for now

    // 2nnn - CALL addr
    var cpu = Cpu.init(.{});
    try cpu.dispatch(0x2100);
    expectEqual(cpu.pc, 0x100);
    expectEqual(cpu.sp, 0x1);
    expectEqual(cpu.stack[0], 0x202);

    // 3xkk - SE Vx, byte
    cpu = Cpu.init(.{});
    try cpu.dispatch(0x3123);
    expectEqual(cpu.pc, 0x202);

    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x03;
    try cpu.dispatch(0x3103);
    expectEqual(cpu.pc, 0x204);

    // 4xkk - SNE Vx, byte
    cpu = Cpu.init(.{});
    try cpu.dispatch(0x4123);
    expectEqual(cpu.pc, 0x204);

    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x03;
    try cpu.dispatch(0x4103);
    expectEqual(cpu.pc, 0x202);

    // 5xy0 - SE Vx, Vy
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x03;
    cpu.registers[2] = 0x04;
    try cpu.dispatch(0x5120);
    expectEqual(cpu.pc, 0x202);

    // 6xkk - LD Vx, byte
    cpu = Cpu.init(.{});
    try cpu.dispatch(0x6102);
    expectEqual(cpu.registers[1], 0x02);

    // 7xkk - ADD Vx,
    cpu = Cpu.init(.{});
    try cpu.dispatch(0x7102);
    expectEqual(cpu.registers[1], 0x02);

    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x01;
    try cpu.dispatch(0x7102);
    expectEqual(cpu.registers[1], 0x03);

    // 8xy0 - LD Vx, Vy
    cpu = Cpu.init(.{});
    cpu.registers[2] = 0x01;
    try cpu.dispatch(0x8120);
    expectEqual(cpu.registers[1], 0x01);

    // 8xy1 - OR Vx, Vy
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x10;
    cpu.registers[2] = 0x01;
    try cpu.dispatch(0x8121);
    expectEqual(cpu.registers[1], 0x11);

    // 8xy2 - AND Vx, Vy
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x10;
    cpu.registers[2] = 0x01;
    try cpu.dispatch(0x8122);
    expectEqual(cpu.registers[1], 0x00);

    // 8xy3 - XOR Vx, Vy
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x01;
    cpu.registers[2] = 0x01;
    try cpu.dispatch(0x8123);
    expectEqual(cpu.registers[1], 0x00);

    // 8xy4 - ADD Vx, Vy
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x01;
    cpu.registers[2] = 0x01;
    try cpu.dispatch(0x8124);
    expectEqual(cpu.registers[1], 0x2);
    expectEqual(cpu.registers[0xF], 0x0);

    cpu = Cpu.init(.{});
    cpu.registers[1] = 0xFF;
    cpu.registers[2] = 0x03;
    try cpu.dispatch(0x8124);
    expectEqual(cpu.registers[1], 0x2);
    expectEqual(cpu.registers[0xF], 0x1);

    // 8xy5 - SUB Vx, Vy
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0xFF;
    cpu.registers[2] = 0x03;
    try cpu.dispatch(0x8125);
    expectEqual(cpu.registers[1], 0xFC);
    expectEqual(cpu.registers[0xF], 0x1);

    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x02;
    cpu.registers[2] = 0x03;
    try cpu.dispatch(0x8125);
    expectEqual(cpu.registers[1], 0xFF);
    expectEqual(cpu.registers[0xF], 0x0);

    // 8xy6 - SHR Vx {, Vy}
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x03;
    try cpu.dispatch(0x8126);
    expectEqual(cpu.registers[1], 0x1);
    expectEqual(cpu.registers[0xF], 0x1);

    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x02;
    try cpu.dispatch(0x8126);
    expectEqual(cpu.registers[1], 0x1);
    expectEqual(cpu.registers[0xF], 0x0);

    // 8xy7 - SUBN Vx, Vy
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x03;
    cpu.registers[2] = 0xFF;
    try cpu.dispatch(0x8127);
    expectEqual(cpu.registers[1], 0xFC);
    expectEqual(cpu.registers[0xF], 0x1);

    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x03;
    cpu.registers[2] = 0x02;
    try cpu.dispatch(0x8127);
    expectEqual(cpu.registers[1], 0xFF);
    expectEqual(cpu.registers[0xF], 0x0);

    // 8xyE - SHL Vx {, Vy}
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x01;
    try cpu.dispatch(0x812E);
    expectEqual(cpu.registers[1], 0x2);
    expectEqual(cpu.registers[0xF], 0x0);

    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x81;
    try cpu.dispatch(0x812E);
    expectEqual(cpu.registers[1], 0x2);
    expectEqual(cpu.registers[0xF], 0x1);

    // 9xy0 - SNE Vx, Vy
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x01;
    cpu.registers[2] = 0x02;
    try cpu.dispatch(0x9120);
    expectEqual(cpu.pc, 0x204);

    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x01;
    cpu.registers[2] = 0x01;
    try cpu.dispatch(0x9120);
    expectEqual(cpu.pc, 0x202);

    // Annn - LD I, addr
    cpu = Cpu.init(.{});
    try cpu.dispatch(0xA100);
    expectEqual(cpu.index_register, 0x100);

    // Bnnn - JP V0, addr
    cpu = Cpu.init(.{});
    try cpu.dispatch(0xB210);
    expectEqual(cpu.pc, 0x210);

    cpu = Cpu.init(.{});
    cpu.registers[0] = 0x01;
    try cpu.dispatch(0xB210);
    expectEqual(cpu.pc, 0x211);

    // Cxkk - RND Vx, byte
    // TODO: implement a way to inject the random position to opcode
    cpu = Cpu.init(.{});
    try cpu.dispatch(0xC110);
    expectEqual(cpu.pc, 0x202);

    // Dxyn - DRW Vx, Vy, nibble
    // TODO: Implement and test video output
    cpu = Cpu.init(.{});
    cpu.index_register = 0x200;
    cpu.memory[0x200] = 0x01;
    try cpu.dispatch(0xD001);
    expectEqual(cpu.video[0], 0x00);
    expectEqual(cpu.registers[0xF], 0x0);

    cpu = Cpu.init(.{});
    cpu.index_register = 0x200;
    cpu.memory[0x200] = 0x01;
    cpu.video[0x7] = 0x01;
    try cpu.dispatch(0xD001);
    expectEqual(cpu.video[0x7], 0x00);
    expectEqual(cpu.registers[0xF], 0x1);

    // Ex9E - SKP Vx
    cpu = Cpu.init(.{});
    cpu.registers[0x01] = 0x02;
    cpu.keypad.keys[0x02] = 0x1;
    try cpu.dispatch(0xE19E);
    expectEqual(cpu.pc, 0x204);

    // ExA1 - SKNP Vx
    cpu = Cpu.init(.{});
    cpu.registers[0x01] = 0x02;
    cpu.keypad.keys[0x02] = 0x1;
    try cpu.dispatch(0xE1A1);
    expectEqual(cpu.pc, 0x202);

    // Fx07 - LD Vx, DT
    cpu = Cpu.init(.{ .delay_timer = 0x01 });
    try cpu.dispatch(0xF107);
    expectEqual(cpu.registers[1], 0x01);

    // Fx15 - LD DT, Vx
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x05;
    try cpu.dispatch(0xF115);
    expectEqual(cpu.delay_timer, 0x05);

    // Fx18 - LD ST, Vx
    cpu = Cpu.init(.{});
    cpu.registers[1] = 0x05;
    try cpu.dispatch(0xF118);
    expectEqual(cpu.sound_timer, 0x05);

    // Fx29 - LD F, Vx
    cpu = Cpu.init(.{});
    try cpu.dispatch(0xF029);
    expectEqual(cpu.index_register, 0x00);

    cpu = Cpu.init(.{});
    cpu.registers[0x01] = 0x01;
    try cpu.dispatch(0xF129);
    expectEqual(cpu.index_register, 0x05);

    cpu = Cpu.init(.{});
    cpu.registers[0x02] = 0x02;
    try cpu.dispatch(0xF229);
    expectEqual(cpu.index_register, 0x0A);

    // Fx33 - LD B, Vx
    cpu = Cpu.init(.{});
    cpu.registers[0] = 0xFF;
    cpu.index_register = 0x200;
    try cpu.dispatch(0xF033);
    expectEqual(cpu.memory[0x200], 0x02);
    expectEqual(cpu.memory[0x201], 0x05);
    expectEqual(cpu.memory[0x202], 0x05);

    // Fx55 - LD [I], Vx
    cpu = Cpu.init(.{});
    cpu.registers[0] = 0x03;
    cpu.registers[1] = 0x02;
    cpu.registers[2] = 0x01;
    cpu.index_register = 0x220;
    try cpu.dispatch(0xF255);
    expectEqual(cpu.memory[0x220], 0x03);
    expectEqual(cpu.memory[0x221], 0x02);
    expectEqual(cpu.memory[0x222], 0x01);

    // Fx65 - LD Vx, [I]
    cpu = Cpu.init(.{});
    cpu.memory[0x200] = 0x01;
    cpu.memory[0x201] = 0x02;
    cpu.index_register = 0x200;
    try cpu.dispatch(0xF165);
    expectEqual(cpu.registers[0], 0x01);
    expectEqual(cpu.registers[1], 0x02);
    expectEqual(cpu.registers[2], 0x00);

    cpu = Cpu.init(.{});
    cpu.memory[0x200] = 0x01;
    cpu.memory[0x201] = 0x02;
    cpu.index_register = 0x200;
    try cpu.dispatch(0xF265);
    expectEqual(cpu.registers[0], 0x01);
    expectEqual(cpu.registers[1], 0x02);
}
