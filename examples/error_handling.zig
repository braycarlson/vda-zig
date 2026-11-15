const std = @import("std");
const vd = @import("vd");

pub fn main() !void {
    try vd.com.initialize(vd.com.COINIT_MULTITHREADED);
    defer vd.com.uninitialize();

    var service = try vd.Service.init();
    defer service.deinit();

    std.debug.print("Testing error cases...\n", .{});
    std.debug.print("----------------------------------------\n", .{});

    if (service.getWindowDesktopIndex(9999999)) |_| {
        std.debug.print("FAIL: expected error for invalid hwnd\n", .{});
    } else |err| {
        std.debug.print("Invalid hwnd desktop query: {}\n", .{err});
    }

    if (service.moveWindowToDesktop(9999999, 0)) |_| {
        std.debug.print("FAIL: expected error for invalid hwnd\n", .{});
    } else |err| {
        std.debug.print("Move invalid hwnd: {}\n", .{err});
    }

    if (service.isPinnedWindow(9999999)) |_| {
        std.debug.print("FAIL: expected error for invalid hwnd\n", .{});
    } else |err| {
        std.debug.print("Pin query invalid hwnd: {}\n", .{err});
    }

    if (service.isPinnedApp(9999999)) |_| {
        std.debug.print("FAIL: expected error for invalid hwnd\n", .{});
    } else |err| {
        std.debug.print("App pin query invalid hwnd: {}\n", .{err});
    }

    std.debug.print("----------------------------------------\n", .{});
    std.debug.print("Done.\n", .{});
}
