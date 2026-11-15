const std = @import("std");
const vd = @import("vd");

pub fn main() !void {
    try vd.com.initialize(vd.com.COINIT_MULTITHREADED);
    defer vd.com.uninitialize();

    var service = try vd.Service.init();
    defer service.deinit();

    var name_buf: [vd.NAME_LEN_MAX]u8 = undefined;
    const original_name = try service.getDesktopName(0, &name_buf);

    var saved: [vd.NAME_LEN_MAX]u8 = undefined;
    const saved_len = original_name.len;

    @memcpy(saved[0..saved_len], original_name);

    std.debug.print("Desktop 0 name: \"{s}\"\n", .{original_name});

    std.debug.print("Renaming to \"Example Desktop\"...\n", .{});
    try service.setDesktopName(0, "Example Desktop");

    const renamed_name = try service.getDesktopName(0, &name_buf);

    std.debug.print("Desktop 0 name: \"{s}\"\n", .{renamed_name});

    std.debug.print("Restoring to \"{s}\"...\n", .{saved[0..saved_len]});
    try service.setDesktopName(0, saved[0..saved_len]);

    const restored_name = try service.getDesktopName(0, &name_buf);

    std.debug.print("Desktop 0 name: \"{s}\"\n", .{restored_name});
    std.debug.print("Done.\n", .{});
}
