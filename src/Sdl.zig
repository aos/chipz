const std = @import("std");
const c = @import("c.zig");

const Sdl = @This();

const Config = struct {
    pixel_size: c_int = 8,
};

// only support a few events
pub const EventType = enum {
    quit,
    keyup,
    keydown,
};

// supported keys
const SupportedKeys = [_]c_int{
    c.SDL_SCANCODE_1,
    c.SDL_SCANCODE_2,
    c.SDL_SCANCODE_3,
    c.SDL_SCANCODE_4,
    c.SDL_SCANCODE_Q,
    c.SDL_SCANCODE_W,
    c.SDL_SCANCODE_E,
    c.SDL_SCANCODE_R,
    c.SDL_SCANCODE_A,
    c.SDL_SCANCODE_S,
    c.SDL_SCANCODE_D,
    c.SDL_SCANCODE_F,
    c.SDL_SCANCODE_Z,
    c.SDL_SCANCODE_X,
    c.SDL_SCANCODE_C,
    c.SDL_SCANCODE_V,
};

window: *c.SDL_Window,
renderer: *c.SDL_Renderer,
texture: *c.SDL_Texture,
rgba_buffer: [64 * 32]u32,
sound: struct {
    beep: []u8,
    audio_device: c.SDL_AudioDeviceID,
},

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

    const beep = @embedFile("beep.wav");
    const audio_spec: c.SDL_AudioSpec, const beep_data: []u8 = load_sounds: {
        const audio_rw = c.SDL_RWFromConstMem(beep, beep.len);
        var spec: c.SDL_AudioSpec = undefined;
        var data_ptr: ?[*]u8 = undefined;
        var data_len: u32 = undefined;
        _ = try errify(c.SDL_LoadWAV_RW(audio_rw, 0, &spec, &data_ptr, &data_len));
        errdefer comptime unreachable;

        break :load_sounds .{ spec, data_ptr.?[0..data_len] };
    };
    const audio_device = c.SDL_OpenAudioDevice(
        null,
        0,
        &audio_spec,
        null,
        0,
    );

    return Sdl{
        .window = window,
        .renderer = renderer,
        .texture = texture,
        .rgba_buffer = std.mem.zeroes([64 * 32]u32),
        .sound = .{
            .beep = beep_data,
            .audio_device = audio_device,
        },
    };
}

pub fn deinit(self: *Sdl) void {
    c.SDL_free(self.sound.beep.ptr);
    c.SDL_CloseAudioDevice(self.sound.audio_device);
    c.SDL_DestroyWindow(self.window);
    c.SDL_DestroyRenderer(self.renderer);
    c.SDL_DestroyTexture(self.texture);
    c.SDL_Quit();
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

pub fn poll(_: *Sdl) ?EventType {
    var event: c.SDL_Event = undefined;
    return if (c.SDL_PollEvent(&event) != 0) switch (event.type) {
        c.SDL_QUIT => EventType.quit,
        c.SDL_KEYUP => EventType.keyup,
        c.SDL_KEYDOWN => EventType.keydown,
        else => null,
    } else null;
}

pub fn updateInput(_: *Sdl, input: []bool) void {
    std.log.debug("sdl: update input", .{});
    const state = c.SDL_GetKeyboardState(null);
    for (SupportedKeys, 0..) |k, i| {
        input[i] = state[@intCast(k)] == 1;
    }
}

pub fn playSound(self: *Sdl) !void {
    std.log.debug("sdl: play sound", .{});
    _ = try errify(c.SDL_QueueAudio(
        self.sound.audio_device,
        @ptrCast(self.sound.beep),
        @intCast(self.sound.beep.len),
    ));
    c.SDL_PauseAudioDevice(self.sound.audio_device, 0);
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
