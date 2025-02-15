const std = @import("std");
const c = @import("c.zig");

pub fn run_demo() void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS | c.SDL_INIT_AUDIO) < 0)
        sdlPanic();
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        "SDL basic demo",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        640,
        480,
        c.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer _ = c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer _ = c.SDL_DestroyRenderer(renderer);

    const vertices = [_]c.SDL_Vertex{
        .{
            .position = .{ .x = 400, .y = 150 },
            .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 },
        },
        .{
            .position = .{ .x = 350, .y = 200 },
            .color = .{ .r = 0, .g = 0, .b = 255, .a = 255 },
        },
        .{
            .position = .{ .x = 450, .y = 200 },
            .color = .{ .r = 0, .g = 255, .b = 0, .a = 255 },
        },
    };

    mainLoop: while (true) {
        var ev: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&ev) != 0) {
            switch (ev.type) {
                c.SDL_QUIT => break :mainLoop,
                c.SDL_KEYDOWN => {
                    switch (ev.key.keysym.scancode) {
                        c.SDL_SCANCODE_ESCAPE => break :mainLoop,
                        else => std.log.info("key pressed: {}\n", .{ev.key.keysym.scancode}),
                    }
                },

                else => {},
            }
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0xFF);
        _ = c.SDL_RenderClear(renderer);

        _ = c.SDL_SetRenderDrawColor(renderer, 0xF7, 0xA4, 0x1D, 0xFF);
        _ = c.SDL_RenderDrawRect(renderer, &c.SDL_Rect{
            .x = 270,
            .y = 215,
            .w = 100,
            .h = 50,
        });

        if (@import("builtin").os.tag != .linux) {
            // Ubuntu CI doesn't have this function available yet
            _ = c.SDL_RenderGeometry(
                renderer,
                null,
                &vertices,
                3,
                null,
                0,
            );
        }

        c.SDL_RenderPresent(renderer);
    }
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, c.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
