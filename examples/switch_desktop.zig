const std = @import("std");
const vd = @import("vd");

extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.winapi) void;

pub fn main() !void {
    try vd.com.initialize(vd.com.COINIT_MULTITHREADED);
    defer vd.com.uninitialize();

    var service = try vd.Service.init();
    defer service.deinit();

    const count = try service.getDesktopCount();
    const original = try service.getDesktopIndexCurrent();

    std.debug.print("Current desktop: {d} of {d}\n", .{ original, count });

    if (count < 2) {
        std.debug.print("Need at least 2 desktops.\n", .{});

        return;
    }

    std.debug.print("Switching to desktop 0...\n", .{});
    try service.switchDesktop(0);
    std.debug.print("  Verified: {d}\n", .{try service.getDesktopIndexCurrent()});
    Sleep(400);

    std.debug.print("Switching to desktop 1...\n", .{});
    try service.switchDesktop(1);
    std.debug.print("  Verified: {d}\n", .{try service.getDesktopIndexCurrent()});
    Sleep(400);

    std.debug.print("Switching back to desktop {d}...\n", .{original});
    try service.switchDesktop(original);
    std.debug.print("  Verified: {d}\n", .{try service.getDesktopIndexCurrent()});
    std.debug.print("Done.\n", .{});
}
