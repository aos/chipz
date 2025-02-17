const std = @import("std");
const c = @import("c.zig");

const Sdl = @This();

const Config = struct {
    pixel_size: c_int = 8,
    width: c_int = 64,
    height: c_int = 32,
};

window: *c.SDL_Window,
renderer: *c.SDL_Renderer,
texture: *c.SDL_Texture,

pub fn init(config: Config) !Sdl {
    _ = try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS | c.SDL_INIT_AUDIO));

    const virtual_width = config.width * config.pixel_size;
    const virtual_height = config.height * config.pixel_size;

    const window = try errify(c.SDL_CreateWindow(
        "chipz",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        virtual_width,
        virtual_height,
        c.SDL_WINDOW_SHOWN,
    ));

    const renderer = try errify(c.SDL_CreateRenderer(
        window,
        -1,
        c.SDL_RENDERER_ACCELERATED,
    ));

    const texture = try errify(c.SDL_CreateTexture(
        renderer,
        c.SDL_PIXELFORMAT_RGBA8888,
        c.SDL_TEXTUREACCESS_STATIC,
        config.width,
        config.height,
    ));

    return Sdl{
        .window = window,
        .renderer = renderer,
        .texture = texture,
    };
}

pub fn update(self: *Sdl, pixels: *[64 * 32]u8) void {
    var rgba_buffer = std.mem.zeroes([64 * 32]u32);
    for (pixels, 0..) |p, i| {
        if (p == 1) {
            rgba_buffer[i] = 0xFFFFFFFF;
        }
    }

    _ = c.SDL_UpdateTexture(self.texture, null, &rgba_buffer, 64 * @sizeOf(u32));
}

pub fn render(self: *Sdl) void {
    _ = c.SDL_RenderClear(self.renderer);
    _ = c.SDL_RenderCopy(self.renderer, self.texture, null, null);
    c.SDL_RenderPresent(self.renderer);
}

pub fn deinit(self: *Sdl) void {
    c.SDL_DestroyWindow(self.window);
    c.SDL_DestroyRenderer(self.renderer);
    c.SDL_DestroyTexture(self.texture);
    c.SDL_Quit();
}

/// Converts the return value of an SDL function to an error union.
inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .Bool => void,
    .Pointer, .Optional => @TypeOf(value.?),
    .Int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .Bool => if (!value) error.SdlError,
        .Pointer, .Optional => value orelse error.SdlError,
        .Int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}
