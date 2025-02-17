const std = @import("std");
const c = @import("c.zig");
const Chip8 = @import("Chip8.zig");
const Sdl = @import("Sdl.zig");

pub fn main() !void {
    // TODO: configurable debug output

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

    std.debug.print("rom_path: {s}\n", .{rom_path});

    // Init emulator and load ROM
    var c8 = Chip8.init(.{ .debug = true });
    try c8.load(allocator, rom_path);

    // Init SDL
    var sdl = try Sdl.init(.{ .pixel_size = 16 });
    defer sdl.deinit();
    sdl.render(&c8.gfx);

    main_loop: while (true) {
        // Process SDL events
        {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event) != 0) {
                switch (event.type) {
                    c.SDL_QUIT => break :main_loop,
                    else => {
                        std.debug.print("Got event: {any}\n", .{event.type});
                    },
                }
            }

            c.SDL_Delay(17);
        }

        // Game engine
        {
            c8.step();
            if (c8.draw_flag) {
                sdl.render(&c8.gfx);
                c8.draw_flag = false;
            }
        }
        std.time.sleep(std.time.ns_per_s / 60);
    }
}

test {
    _ = Chip8;
}
