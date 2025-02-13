const std = @import("std");
const Chip8 = @import("Chip8.zig");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    // For programs that provide their own entry points instead of relying on SDL's main function
    // macro magic, 'SDL_MAIN_HANDLED' should be defined before including 'SDL_main.h'.
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});

pub fn main() !void {
    // SDL STUFF
    errdefer |err| if (err == error.SdlError) std.log.err("SDL error: {s}", .{c.SDL_GetError()});

    std.log.debug("SDL build time version: {d}.{d}.{d}", .{
        c.SDL_MAJOR_VERSION,
        c.SDL_MINOR_VERSION,
        c.SDL_MICRO_VERSION,
    });
    std.log.debug("SDL build time revision: {s}", .{c.SDL_REVISION});
    {
        const version = c.SDL_GetVersion();
        std.log.debug("SDL runtime version: {d}.{d}.{d}", .{
            c.SDL_VERSIONNUM_MAJOR(version),
            c.SDL_VERSIONNUM_MINOR(version),
            c.SDL_VERSIONNUM_MICRO(version),
        });
        const revision: [*:0]const u8 = c.SDL_GetRevision();
        std.log.debug("SDL runtime revision: {s}", .{revision});
    }

    c.SDL_SetMainReady();
    if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMEPAD)) {
        std.debug.print("SDL error: {s}\n", .{c.SDL_GetError()});
    }

    // SDL

    var aa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = aa.allocator();
    defer aa.deinit();

    var it = try std.process.argsWithAllocator(allocator);

    // skip exe
    _ = it.skip();
    const rom_path = it.next() orelse @panic("You must provide a ROM!\n");

    std.debug.print("rom_path: {s}\n", .{rom_path});

    // TODO: configurable debug output

    // const c8 = Chip8.init(.{ .debug = true });
    // try c8.load(allocator, rom_path);
    // while (true) {
    //     c8.step();
    //     if (c8.draw_flag) {
    //         // draw something using SDL
    //         c8.draw_flag = false;
    //     }
    //     std.time.sleep(std.time.ns_per_s * 1);
    // }
}

test {
    _ = Chip8;
}
