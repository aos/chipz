const std = @import("std");
const c = @import("c.zig");
const Chip8 = @import("Chip8.zig");
const Sdl = @import("Sdl.zig");

pub fn main() !void {
    errdefer |err| if (err == error.SdlError) {
        std.debug.print("SDL error: {s}\n", .{c.SDL_GetError()});
    };

    var aa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = aa.allocator();
    defer aa.deinit();

    var it = try std.process.argsWithAllocator(allocator);

    // skip exe
    _ = it.skip();
    const rom_path = it.next() orelse @panic("You must provide a ROM!\n");

    // Init emulator and load ROM
    var c8 = Chip8.init(.{});
    try c8.load(allocator, rom_path);

    // Init SDL
    var sdl = try Sdl.init(.{ .pixel_size = 16 });
    defer sdl.deinit();
    try sdl.render(&c8.gfx);

    main_loop: while (true) {
        // Process SDL events
        {
            while (sdl.poll()) |event| {
                switch (event) {
                    Sdl.EventType.quit => break :main_loop,
                    else => {},
                }
            }
        }

        sdl.updateInput(&c8.keys);

        // Game engine
        {
            // Cheat a bit and run more opcodes per frame
            for (0..c8.config.opcodes_per_frame + 1) |_| {
                c8.step();
            }

            c8.stepTimers();

            if (c8.draw_flag) {
                try sdl.render(&c8.gfx);
                c8.draw_flag = false;
            }

            if (c8.sound_timer > 0) {
                try sdl.playSound();
            }
        }

        // Run at 60 FPS...
        std.time.sleep(std.time.ns_per_s / 60);
    }
}

test {
    _ = Chip8;
}
