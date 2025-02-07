const std = @import("std");

pub fn main() !void {
    var c8 = Chip8.init(&font_set);
    c8.execute(0xDFA3);
}

const Chip8 = struct {
    memory: [4096]u8,
    graphics: [64 * 32]u8,
    stack: [16]u16,
    key: [16]u8,
    pc: u16 = 0x200, // Program counter starts at 0x200
    // opcode: u16,
    V: [16]u8,
    I: u16,
    sp: u16,
    delay_timer: u8,
    sound_timer: u8,
    draw_flag: bool,

    pub fn init(fs: []const u8) Chip8 {
        var c8 = std.mem.zeroes(Chip8);
        // load font_set
        for (fs, 0x50..) |f, i| {
            c8.memory[i] = f;
        }

        return c8;
    }

    fn step(self: *Chip8) void {
        const opcode = self.memory[self.pc] << 8 | self.memory[self.pc + 1];
        self.pc += 2;

        self.execute(opcode);
    }

    fn execute(self: *Chip8, opcode: u16) void {
        switch (opcode & 0xF000) {
            0x0000 => {
                switch (opcode) {
                    // clear screen
                    0x00E0 => {
                        @memset(&self.graphics, 0);
                    },
                    0x00EE => {
                        // "pop" the last address from the stack
                        self.sp -= 1;
                        self.pc = self.stack[self.sp];
                    },
                    else => {},
                }
            },
            // goto: 1NNN
            0x1000 => {
                self.pc = opcode & 0x0FFF;
            },
            // Calls subroutine: 2NNN
            0x2000 => {
                // push current PC to stack
                self.stack[self.sp] = self.pc;
                self.sp += 1;
                // "call" the subroutine at address
                // returning via 00EE
                self.pc = opcode & 0x0FFF;
            },
            0x3000 => {
                //
            },
            // Set register: 6XNN
            0x6000 => {
                const reg, const value = getXNN(opcode);
                self.V[reg] = value;
            },
            // Add value to register: 7XNN
            0x7000 => {
                const reg, const value = getXNN(opcode);
                self.V[reg] += value;
            },
            0xA000 => {
                self.I = opcode & 0x0FFF;
            },
            // Draw (Vx, Vy, N): DXYN
            0xD000 => {
                const vx, const vy, const n = getXYN(opcode);
                const x = self.V[vx] % 64;
                const y = self.V[vy] % 32;
                self.V[0xF] = 0;
                // each row
                for (0..n) |row| {
                    // Create a bitset of our sprite row
                    const sprite_row: std.bit_set.IntegerBitSet(8) = .{
                        .mask = self.memory[self.I + row],
                    };
                    for (0..8) |bit| {
                        var gfx = self.graphics[x + bit + ((y + row) * 64)];
                        if (sprite_row.isSet(bit)) {
                            if (gfx == 1) {
                                self.V[0xF] = 1;
                            }
                            // TODO: May need to reference self. directly
                            gfx ^= 1;
                        }
                    }
                }

                self.draw_flag = true;
            },
            else => unreachable,
        }
    }
};

fn getLowerBits(comptime T: type, opcode: u16) T {
    const lower: T = @truncate(opcode);
    return lower;
}

fn getXNN(opcode: u16) struct { u4, u8 } {
    const reg = getLowerBits(u4, opcode >> 8);
    const value = getLowerBits(u8, opcode);
    return .{ reg, value };
}

fn getXYN(opcode: u16) struct { u4, u4, u4 } {
    const vx = getLowerBits(u4, opcode >> 8);
    const vy = getLowerBits(u4, opcode >> 4);
    const n = getLowerBits(u4, opcode);
    return .{ vx, vy, n };
}

// Put this in memory at 0x50 - 0x9F
const font_set = [_]u8{
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

test "00E0" {
    const cleared = std.mem.zeroes([64 * 32]u8);
    var c8 = Chip8.init(&font_set);
    c8.execute(0x00E0);
    try std.testing.expectEqualSlices(u8, &c8.graphics, &cleared);
}

test "subroutines: 2NNN -> 00EE" {
    var c8 = Chip8.init(&font_set);
    c8.pc = 0x0345;
    // call subroutine
    c8.execute(0x2994);
    c8.execute(0x00EE);
    // we should now be back at where we started
    try std.testing.expect(c8.pc == 0x0345);
}

test "1NNN" {
    var c8 = Chip8.init(&font_set);
    c8.execute(0x1345);
    try std.testing.expect(c8.pc == 0x0345);
}

test "6XNN" {
    var c8 = Chip8.init(&font_set);
    c8.execute(0x6FA3);
    try std.testing.expect(c8.V[0xF] == 0xA3);
}

test "ANNN" {
    var c8 = Chip8.init(&font_set);
    c8.execute(0xA345);
    try std.testing.expect(c8.I == 0x0345);
}
