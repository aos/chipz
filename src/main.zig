const std = @import("std");
const Chip8 = @import("Chip8.zig");

pub fn main() !void {
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
    // c8.start();
}

test {
    _ = Chip8;
}
