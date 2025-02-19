const std = @import("std");
const c = @import("c.zig");

const Sdl = @This();

const Config = struct {
    pixel_size: c_int = 8,
};

window: *c.SDL_Window,
renderer: *c.SDL_Renderer,
texture: *c.SDL_Texture,
rgba_buffer: [64 * 32]u32,

pub fn init(config: Config) !Sdl {
    std.log.debug("sdl: init - config: {any}", .{config});
    _ = try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS | c.SDL_INIT_AUDIO));

    const virtual_width = 64 * config.pixel_size;
    const virtual_height = 32 * config.pixel_size;

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
        64,
        32,
    ));

    return Sdl{
        .window = window,
        .renderer = renderer,
        .texture = texture,
        .rgba_buffer = std.mem.zeroes([64 * 32]u32),
    };
}

pub fn render(self: *Sdl, pixels: *[64 * 32]u1) !void {
    std.log.debug("sdl: render", .{});
    @memset(&self.rgba_buffer, 0);
    for (pixels, 0..) |p, i| {
        if (p == 1) {
            self.rgba_buffer[i] = 0xFFFFFFFF;
        }
    }

    _ = try errify(c.SDL_UpdateTexture(self.texture, null, &self.rgba_buffer, 64 * @sizeOf(u32)));
    _ = try errify(c.SDL_RenderClear(self.renderer));
    _ = try errify(c.SDL_RenderCopy(self.renderer, self.texture, null, null));
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
