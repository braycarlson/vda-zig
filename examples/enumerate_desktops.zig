const std = @import("std");
const vd = @import("vd");

pub fn main() !void {
    try vd.com.initialize(vd.com.COINIT_MULTITHREADED);
    defer vd.com.uninitialize();

    var service = try vd.Service.init();
    defer service.deinit();

    const count = try service.getDesktopCount();
    const current = try service.getDesktopIndexCurrent();

    std.debug.print("Virtual Desktops: {d}\n", .{count});
    std.debug.print("----------------------------------------\n", .{});

    var i: u32 = 0;

    while (i < count) : (i += 1) {
        var name_buf: [vd.NAME_LEN_MAX]u8 = undefined;
        const name = service.getDesktopName(i, &name_buf) catch "?";
        const marker: []const u8 = if (i == current) " <-- active" else "";

        std.debug.print("  [{d}] {s}{s}\n", .{ i, name, marker });
    }

    std.debug.print("----------------------------------------\n", .{});
}
