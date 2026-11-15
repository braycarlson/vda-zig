const std = @import("std");
const vd = @import("vd");

extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.winapi) void;

pub fn main() !void {
    try vd.com.initialize(vd.com.COINIT_MULTITHREADED);
    defer vd.com.uninitialize();

    var service = try vd.Service.init();
    defer service.deinit();

    const desktop_count_before = try service.getDesktopCount();

    std.debug.print("Desktops before: {d}\n", .{desktop_count_before});

    std.debug.print("Creating desktop...\n", .{});
    const created_index = try service.createDesktop();

    std.debug.print("Desktops after: {d}\n", .{try service.getDesktopCount()});
    std.debug.print("New desktop index: {d}\n", .{created_index});

    std.debug.print("Switching to new desktop...\n", .{});
    try service.switchDesktop(created_index);
    Sleep(2000);

    std.debug.print("Switching back to desktop 0...\n", .{});
    try service.switchDesktop(0);
    Sleep(500);

    std.debug.print("Removing desktop {d}...\n", .{created_index});
    try service.removeDesktop(created_index, 0);
    std.debug.print("Desktops final: {d}\n", .{try service.getDesktopCount()});
    std.debug.print("Done.\n", .{});
}
