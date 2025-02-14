const std = @import("std");
const Chip8 = @import("Chip8.zig");
const sdl = @import("Sdl.zig");

pub fn main() !void {
    var aa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = aa.allocator();
    defer aa.deinit();

    var it = try std.process.argsWithAllocator(allocator);

    // skip exe
    _ = it.skip();
    const rom_path = it.next() orelse @panic("You must provide a ROM!\n");

    std.debug.print("rom_path: {s}\n", .{rom_path});

    // sdl.run_demo();

    // TODO: configurable debug output

    var c8 = Chip8.init(.{ .debug = true });
    try c8.load(allocator, rom_path);
    while (true) {
        c8.step();
        if (c8.draw_flag) {
            c8.print();
            // draw something using SDL
            c8.draw_flag = false;
        }
        std.time.sleep(std.time.ns_per_s * 1);
    }
}

test {
    _ = Chip8;
}
