const std = @import("std");
const font_set = @import("font_set.zig").font_set;

const Chip8 = @This();

memory: [4096]u8, // 0xFFF
gfx: [64 * 32]u1,
stack: [16]u16,
keys: [16]bool, // 0 - F
pc: u16 = 0x200, // Program counter starts at 0x200
V: [16]u8,
I: u16,
sp: u16,
delay_timer: u8,
sound_timer: u8,
draw_flag: bool,
config: Config = .{},

const Config = struct {
    opcodes_per_frame: usize = 10,
    set_vx_8XY6E: bool = false,
    set_vx_BNNN: bool = false,
    inc_i_FX55: bool = false,
};

pub fn init(config: Config) Chip8 {
    std.log.debug("chip8: init - config: {any}", .{config});
    var c8 = std.mem.zeroInit(Chip8, .{ .config = config });
    // load font_set
    for (font_set, 0x50..) |f, i| {
        c8.memory[i] = f;
    }
    return c8;
}

pub fn load(self: *Chip8, allocator: std.mem.Allocator, rom_path: []const u8) !void {
    std.log.debug("loading rom: {s}", .{rom_path});
    const file = try std.fs.cwd().openFile(rom_path, .{});
    defer file.close();
    const stat = try file.stat();
    const buf: []u8 = try file.readToEndAlloc(allocator, stat.size);

    @memcpy(self.memory[self.pc .. self.pc + buf.len], buf);
}

pub fn start(self: *Chip8) void {
    while (true) {
        self.step();

        if (self.draw_flag) {
            self.print();
            self.draw_flag = false;
        }
        std.time.sleep(std.time.ns_per_s * 1);
    }
}

pub fn step(self: *Chip8) void {
    const opcode = @as(u16, self.memory[self.pc]) << 8 | self.memory[self.pc + 1];
    self.pc += 2;
    self.execute(opcode);
}

pub fn stepTimers(self: *Chip8) void {
    if (self.delay_timer > 0) {
        self.delay_timer -= 1;
    }

    if (self.sound_timer > 0) {
        self.sound_timer -= 1;
    }
}

fn execute(self: *Chip8, opcode: u16) void {
    switch (opcode & 0xF000) {
        0x0000 => {
            switch (opcode) {
                // clear screen
                0x00E0 => {
                    @memset(&self.gfx, 0);
                    std.log.debug("[{X}]", .{opcode});
                },
                0x00EE => {
                    // "pop" the last address from the stack
                    self.sp -= 1;
                    self.pc = self.stack[self.sp];
                    std.log.debug("[{X}]\tpc: {X}", .{ opcode, self.pc });
                },
                else => {
                    std.log.warn("unknown instruction: {X}\n", .{opcode});
                },
            }
        },
        // goto: 1NNN
        0x1000 => {
            self.pc = opcode & 0x0FFF;
            std.log.debug("[{X}]\tpc: {X}", .{ opcode, self.pc });
        },
        // Calls subroutine: 2NNN
        0x2000 => {
            // push current PC to stack
            self.stack[self.sp] = self.pc;
            self.sp += 1;
            // "call" the subroutine at address
            // returning via 00EE
            self.pc = opcode & 0x0FFF;

            std.log.debug("[{X}]\told pc: {X}\tnew pc: {X}", .{
                opcode,
                self.stack[self.sp - 1],
                self.pc,
            });
        },
        // Conditional skip if true: 3XNN
        0x3000 => {
            const reg, const value = getXNN(opcode);
            if (self.V[reg] == value) {
                self.pc += 2;
            }
        },
        // Conditional skip if false: 4XNN
        0x4000 => {
            const reg, const value = getXNN(opcode);
            if (self.V[reg] != value) {
                self.pc += 2;
            }
        },
        // Conditional skip registers: 5XY0
        0x5000 => {
            const vx, const vy, _ = getXYN(opcode);
            if (self.V[vx] == self.V[vy]) {
                self.pc += 2;
            }
        },
        // Set register: 6XNN
        0x6000 => {
            const reg, const value = getXNN(opcode);
            self.V[reg] = value;
        },
        // Add value to register: 7XNN
        0x7000 => {
            const reg, const value = getXNN(opcode);
            self.V[reg], _ = @addWithOverflow(self.V[reg], value);
        },
        0x8000 => {
            switch (opcode & 0x000F) {
                0x0 => {
                    const vx, const vy, _ = getXYN(opcode);
                    self.V[vx] = self.V[vy];
                },
                0x1 => {
                    const vx, const vy, _ = getXYN(opcode);
                    self.V[vx] |= self.V[vy];
                },
                0x2 => {
                    const vx, const vy, _ = getXYN(opcode);
                    self.V[vx] &= self.V[vy];
                },
                0x3 => {
                    const vx, const vy, _ = getXYN(opcode);
                    self.V[vx] ^= self.V[vy];
                },
                // addition with overflow
                0x4 => {
                    const vx, const vy, _ = getXYN(opcode);
                    const result, const overflow = @addWithOverflow(self.V[vx], self.V[vy]);
                    self.V[vx] = result;
                    self.V[0xF] = overflow;
                },
                // subtraction with underflow
                0x5 => {
                    self.V[0xF] = 1;
                    const vx, const vy, _ = getXYN(opcode);
                    const result, const overflow = @subWithOverflow(self.V[vx], self.V[vy]);
                    self.V[vx] = result;
                    self.V[0xF] ^= overflow;
                },
                0x6 => {
                    const vx, const vy, _ = getXYN(opcode);
                    self.V[0xF] = 0;
                    if (self.config.set_vx_8XY6E) {
                        self.V[vx] = self.V[vy];
                    }
                    const overflow = (self.V[vx] & 0x1);
                    self.V[0xF] ^= overflow;
                    self.V[vx] >>= 1;
                },
                0x7 => {
                    self.V[0xF] = 1;
                    const vx, const vy, _ = getXYN(opcode);
                    const result, const overflow = @subWithOverflow(self.V[vy], self.V[vx]);
                    self.V[vx] = result;
                    self.V[0xF] ^= overflow;
                },
                0xE => {
                    const vx, const vy, _ = getXYN(opcode);
                    self.V[0xF] = 0;
                    if (self.config.set_vx_8XY6E) {
                        self.V[vx] = self.V[vy];
                    }
                    const result, const overflow = @shlWithOverflow(self.V[vx], 1);
                    self.V[vx] = result;
                    self.V[0xF] ^= overflow;
                },
                else => {
                    std.log.warn("unknown instruction: {X}\n", .{opcode});
                },
            }
        },
        // Conditional skip registers: 9XY0
        0x9000 => {
            const vx, const vy, _ = getXYN(opcode);
            if (self.V[vx] != self.V[vy]) {
                self.pc += 2;
            }
        },
        // Set index register: ANNN
        0xA000 => {
            self.I = opcode & 0x0FFF;
            std.log.debug("[{X}]\t{X}", .{ opcode, self.I });
        },
        // Jump with offset: BNNN
        0xB000 => {
            if (self.config.set_vx_BNNN) {
                const reg, _ = getXNN(opcode);
                const address = opcode & 0x0FFF;
                self.pc = self.V[reg] + address;
            } else {
                const address = opcode & 0x0FFF;
                std.log.debug("[{X}]\t{X}", .{ opcode, address });
                self.pc = self.V[0] + address;
            }
        },
        // Random: CNNN
        0xC000 => {
            const vx, const n = getXNN(opcode);
            const r = std.crypto.random.intRangeAtMostBiased(u8, 0, 255);
            self.V[vx] = r & n;
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
                    const pixel = x + bit + ((y + row) * 64);
                    if (sprite_row.isSet(7 - bit)) {
                        if (self.gfx[pixel] == 1) {
                            self.V[0xF] = 1;
                        }
                        self.gfx[pixel] ^= 1;
                    }
                }
            }
            self.draw_flag = true;
        },
        // Skip if key: EX9E/EX0A
        0xE000 => {
            switch (opcode & 0x00FF) {
                0x009E => {
                    const reg, _ = getXNN(opcode);
                    const k = self.V[reg];
                    if (self.keys[k]) {
                        self.pc += 2;
                    }
                },
                0x00A1 => {
                    const reg, _ = getXNN(opcode);
                    const k = self.V[reg];
                    if (!self.keys[k]) {
                        self.pc += 2;
                    }
                },
                else => {
                    std.log.warn("unknown instruction: {X}\n", .{opcode});
                },
            }
        },
        0xF000 => {
            switch (opcode & 0x00FF) {
                0x0007 => {
                    const reg, _ = getXNN(opcode);
                    self.V[reg] = self.delay_timer;
                },
                0x0015 => {
                    const reg, _ = getXNN(opcode);
                    self.delay_timer = self.V[reg];
                },
                0x0018 => {
                    const reg, _ = getXNN(opcode);
                    self.sound_timer = self.V[reg];
                },
                0x001E => {
                    const reg, _ = getXNN(opcode);
                    const add = self.I + self.V[reg];
                    if ((add & 0x1000) >= 0x1000) {
                        self.V[0xF] = 1;
                    }
                    self.I = add;
                },
                // Wait for key input: FX0A
                // FIXME: this only works to find the first key
                // what happens if we want multiple keys?
                0x000A => {
                    const key_index: ?u8 = for (self.keys, 0..) |k, i| {
                        if (k) break @intCast(i);
                    } else null;

                    if (key_index) |idx| {
                        const reg, _ = getXNN(opcode);
                        self.V[reg] = idx;
                    } else {
                        std.log.debug("[{X}]", .{opcode});
                        self.pc -= 2;
                    }
                },
                0x0029 => {
                    const reg, _ = getXNN(opcode);
                    const char = self.V[reg];
                    self.I = self.memory[0x50] + char;
                },
                0x0033 => {
                    const reg, _ = getXNN(opcode);
                    const num = self.V[reg];
                    var n: u8 = 1;
                    while (n < 4) : (n += 1) {
                        const power = std.math.pow(u16, 10, n);
                        const new = @mod(num, power);
                        const final = @divTrunc(new, power / 10);
                        self.memory[self.I + (3 - n)] = @intCast(final);
                    }
                },
                0x0055 => {
                    const reg, _ = getXNN(opcode);
                    var x: u8 = 0;
                    while (x <= reg) : (x += 1) {
                        self.memory[self.I + x] = self.V[x];
                    }
                    if (self.config.inc_i_FX55) {
                        self.I = reg + x + 1;
                    }
                },
                0x0065 => {
                    const reg, _ = getXNN(opcode);
                    var x: u8 = 0;
                    while (x <= reg) : (x += 1) {
                        self.V[x] = self.memory[self.I + x];
                    }
                    if (self.config.inc_i_FX55) {
                        self.I = reg + x + 1;
                    }
                },
                else => {
                    std.log.warn("unknown instruction: {X}\n", .{opcode});
                },
            }
        },
        else => {
            std.log.warn("unknown instruction: {X}\n", .{opcode});
        },
    }
}

fn print(self: *Chip8) void {
    for (0..32) |y| {
        for (0..64) |x| {
            const pixel = self.gfx[x + (y * 64)];
            if (pixel == 0) {
                std.debug.print(" ", .{});
            } else {
                std.debug.print("█", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

fn getLowerBits(comptime T: type, opcode: u16) T {
    const lower: T = @truncate(opcode);
    return lower;
}

fn getXNN(opcode: u16) struct { u4, u8 } {
    const reg = getLowerBits(u4, opcode >> 8);
    const value = getLowerBits(u8, opcode);

    std.log.debug("[{X}]\treg: {X}\tvalue: {X}", .{ opcode, reg, value });

    return .{ reg, value };
}

fn getXYN(opcode: u16) struct { u4, u4, u4 } {
    const vx = getLowerBits(u4, opcode >> 8);
    const vy = getLowerBits(u4, opcode >> 4);
    const n = getLowerBits(u4, opcode);

    std.log.debug("[{X}]\tx: {X}\ty: {X}\tn: {X}", .{ opcode, vx, vy, n });

    return .{ vx, vy, n };
}

test "00E0" {
    const cleared = std.mem.zeroes([64 * 32]u1);
    var c8 = Chip8.init(.{});
    @memcpy(c8.gfx[0..5], &[_]u1{ 1, 0, 0, 0, 1 });
    c8.execute(0x00E0);
    try std.testing.expectEqualSlices(u1, &c8.gfx, &cleared);
}

test "1NNN" {
    var c8 = Chip8.init(.{});
    c8.execute(0x1345);
    try std.testing.expect(c8.pc == 0x0345);
}

test "subroutines: 2NNN -> 00EE" {
    var c8 = Chip8.init(.{});
    c8.pc = 0x0345;
    // call subroutine
    c8.execute(0x2994);
    c8.execute(0x00EE);
    // we should now be back at where we started
    try std.testing.expect(c8.pc == 0x0345);
}

test "3XNN" {
    var c8 = Chip8.init(.{});
    const initial_pc = c8.pc;
    c8.V[0xD] = 0x55;
    c8.execute(0x3D55);
    try std.testing.expect(c8.pc == (initial_pc + 2));

    c8.V[0xA] = 0x33;
    const next_pc = c8.pc;
    c8.execute(0x3A29);
    try std.testing.expect(c8.pc == next_pc);
}

test "4XNN" {
    var c8 = Chip8.init(.{});
    const initial_pc = c8.pc;
    c8.V[0xD] = 0x55;
    c8.execute(0x4D55);
    try std.testing.expect(c8.pc == initial_pc);

    c8.V[0xA] = 0x33;
    const next_pc = c8.pc;
    c8.execute(0x4A29);
    try std.testing.expect(c8.pc == (next_pc + 2));
}

test "5XY0" {
    var c8 = Chip8.init(.{});
    const initial_pc = c8.pc;
    c8.V[0xA] = 0x3;
    c8.V[0xB] = 0x3;
    c8.execute(0x5AB0);
    try std.testing.expect(c8.pc == (initial_pc + 2));

    const next_pc = c8.pc;
    c8.V[0xA] = 0x3;
    c8.V[0xB] = 0x5;
    c8.execute(0x5AB0);
    try std.testing.expect(c8.pc == next_pc);
}

test "6XNN" {
    var c8 = Chip8.init(.{});
    c8.execute(0x6DA3);
    try std.testing.expect(c8.V[0xD] == 0xA3);
}

test "8XY1" {
    var c8 = Chip8.init(.{});
    c8.V[0xA] = 0xF0;
    c8.V[0xB] = 0x0F;
    c8.execute(0x8AB1);
    try std.testing.expect(c8.V[0xA] == 0xFF);
}

test "8XY2" {
    var c8 = Chip8.init(.{});
    c8.V[0xA] = 0xF0;
    c8.V[0xB] = 0x0F;
    c8.execute(0x8AB2);
    try std.testing.expect(c8.V[0xA] == 0x0);
}

test "8XY3" {
    var c8 = Chip8.init(.{});
    c8.V[0xA] = 0xF0;
    c8.V[0xB] = 0x0F;
    c8.execute(0x8AB3);
    try std.testing.expect(c8.V[0xA] == 0xFF);
}

test "8XY4" {
    var c8 = Chip8.init(.{});
    c8.V[0xA] = 255;
    c8.V[0xB] = 5;
    c8.execute(0x8AB4);
    try std.testing.expect(c8.V[0xA] == 0x4);
    try std.testing.expect(c8.V[0xF] == 0x1);
}

test "8XY5" {
    var c8 = Chip8.init(.{});
    c8.V[0xA] = 3;
    c8.V[0xB] = 9;
    c8.execute(0x8AB5);
    try std.testing.expect(c8.V[0xA] == 0xFA);
    try std.testing.expect(c8.V[0xF] == 0x0);

    c8.V[0xA] = 255;
    c8.V[0xB] = 3;
    c8.execute(0x8AB5);
    try std.testing.expect(c8.V[0xA] == 0xFC);
    try std.testing.expect(c8.V[0xF] == 0x1);
}

test "8XY6" {
    var c8 = Chip8.init(.{});
    c8.V[0x3] = 0x3;
    c8.execute(0x8346);
    try std.testing.expect(c8.V[0x3] == 0x1);
    try std.testing.expect(c8.V[0xF] == 0x1);

    c8.V[0x3] = 0x2;
    c8.execute(0x8346);
    try std.testing.expect(c8.V[0x3] == 0x1);
    try std.testing.expect(c8.V[0xF] == 0x0);
}

test "8XY7" {
    var c8 = Chip8.init(.{});
    c8.V[0x3] = 0x3;
    c8.V[0x4] = 0x9;
    c8.execute(0x8347);
    try std.testing.expect(c8.V[0x3] == 0x6);
    try std.testing.expect(c8.V[0xF] == 0x1);

    c8.V[0x3] = 9;
    c8.V[0x4] = 3;
    c8.execute(0x8347);
    try std.testing.expect(c8.V[0x3] == 0xFA);
    try std.testing.expect(c8.V[0xF] == 0x0);
}

test "8XYE" {
    var c8 = Chip8.init(.{});
    c8.V[0x3] = 0x1;
    c8.execute(0x834E);
    try std.testing.expect(c8.V[0x3] == 0x2);
    try std.testing.expect(c8.V[0xF] == 0x0);

    c8.V[0x3] = 0xF0;
    c8.execute(0x834E);
    try std.testing.expect(c8.V[0x3] == 0xE0);
    try std.testing.expect(c8.V[0xF] == 0x1);
}

test "9XY0" {
    var c8 = Chip8.init(.{});
    const initial_pc = c8.pc;
    c8.V[0xA] = 0x3;
    c8.V[0xB] = 0x3;
    c8.execute(0x9AB0);
    try std.testing.expect(c8.pc == initial_pc);

    const next_pc = c8.pc;
    c8.V[0xA] = 0x3;
    c8.V[0xB] = 0x5;
    c8.execute(0x9AB0);
    try std.testing.expect(c8.pc == (next_pc + 2));
}

test "ANNN" {
    var c8 = Chip8.init(.{});
    c8.execute(0xA345);
    try std.testing.expect(c8.I == 0x0345);
}

test "BNNN" {
    var c8 = Chip8.init(.{});
    c8.V[0x2] = 0x3;
    c8.execute(0xB220);
    try std.testing.expect(c8.pc == 0x220);

    c8.config.set_vx_BNNN = true;
    c8.V[0x2] = 0x3;
    c8.execute(0xB220);
    try std.testing.expect(c8.pc == 0x223);
}

test "CXNN" {
    var c8 = Chip8.init(.{});
    const num = 33;
    c8.V[9] = num;
    c8.execute(0xC945);

    try std.testing.expect(c8.V[9] != num);
}

// TODO: How to test draw (DXYN)?

test "EX9E" {
    var c8 = Chip8.init(.{});
    const current_pc = c8.pc;
    c8.keys[0xF] = true;
    c8.V[0x2] = 0xF;
    c8.execute(0xE29E);
    try std.testing.expect(c8.pc == current_pc + 2);
}

test "EXA1" {
    var c8 = Chip8.init(.{});
    const current_pc = c8.pc;
    c8.keys[0xE] = true;
    c8.V[0x2] = 0xF;
    c8.execute(0xE2A1);
    try std.testing.expect(c8.pc == current_pc + 2);
}

test "FX33" {
    var c8 = Chip8.init(.{});
    c8.I = 0x4FE;
    c8.V[0x2] = 0xF3; // 243
    c8.execute(0xF233);
    try std.testing.expectEqualSlices(
        u8,
        c8.memory[c8.I .. c8.I + 3],
        &[_]u8{ 2, 4, 3 },
    );
}

test "FX55" {
    var c8 = Chip8.init(.{});
    c8.I = 0x6FE;
    var n: u8 = 0;
    while (n < 10) : (n += 1) {
        c8.V[n] = n;
    }

    c8.execute(0xF955);
    try std.testing.expectEqualSlices(
        u8,
        c8.memory[c8.I .. c8.I + 10],
        &[_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
    );
}

test "FX65" {
    var c8 = Chip8.init(.{});
    c8.I = 0x6FE;
    var n: u8 = 0;
    while (n < 10) : (n += 1) {
        c8.memory[c8.I + n] = n;
    }
    c8.execute(0xF965);

    var expected = [_]u8{0} ** 10;
    var y: u8 = 0;
    while (y < 10) : (y += 1) {
        expected[y] = c8.V[y];
    }

    try std.testing.expectEqualSlices(
        u8,
        c8.memory[c8.I .. c8.I + 10],
        &expected,
    );
}

test "load rom into correct address" {
    const rom_path = "roms/1-ibm-logo_1.ch8";
    var aa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = aa.allocator();
    defer aa.deinit();

    var c8 = Chip8.init(.{});
    try c8.load(allocator, rom_path);

    const file = try std.fs.cwd().openFile(rom_path, .{});
    defer file.close();
    const stat = try file.stat();
    const rom_buf: []u8 = try file.readToEndAlloc(allocator, stat.size);

    try std.testing.expectEqualSlices(u8, c8.memory[c8.pc .. c8.pc + rom_buf.len], rom_buf);
}
