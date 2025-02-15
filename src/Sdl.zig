const std = @import("std");
const c = @import("c.zig");

const Sdl = @This();

window: *c.SDL_Window,
renderer: *c.SDL_Renderer,

pub fn init() void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS | c.SDL_INIT_AUDIO) < 0)
        sdlPanic();
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        "chipz",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        640,
        480,
        c.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer _ = c.SDL_DestroyWindow(window);
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, c.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
