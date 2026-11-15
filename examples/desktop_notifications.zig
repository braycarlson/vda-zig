const std = @import("std");
const vd = @import("vd");

extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.winapi) void;

fn onDesktopChanged(old: vd.GUID, new: vd.GUID) void {
    _ = old;
    _ = new;

    std.debug.print("Desktop changed.\n", .{});
}

fn onDesktopCreated(id: vd.GUID) void {
    _ = id;

    std.debug.print("Desktop created.\n", .{});
}

fn onDesktopDestroyed(destroyed: vd.GUID, fallback: vd.GUID) void {
    _ = destroyed;
    _ = fallback;

    std.debug.print("Desktop destroyed.\n", .{});
}

fn onDesktopNameChanged(id: vd.GUID, name: []const u8) void {
    _ = id;

    std.debug.print("Desktop name changed: \"{s}\"\n", .{name});
}

fn onWindowDesktopChanged(handle: isize, desktop: vd.GUID) void {
    const pinned_view = desktop.eql(vd.guid.DESKTOP_ID_PINNED_VIEW);
    const pinned_app = desktop.eql(vd.guid.DESKTOP_ID_PINNED_APP);
    const pinned = pinned_view or pinned_app;

    std.debug.print("Window 0x{x} changed desktop (pinned: {}).\n", .{ handle, pinned });
}

fn onWindowEvent(handle: isize, change: vd.ApplicationViewChange) void {
    const name = std.enums.tagName(vd.ApplicationViewChange, change) orelse "unnamed";

    std.debug.print("Window 0x{x}: {s}\n", .{ handle, name });
}

fn onMultitaskingViewShown(view_type: vd.MultitaskingViewType) void {
    const name = std.enums.tagName(vd.MultitaskingViewType, view_type) orelse "unnamed";

    std.debug.print("Shown: {s}\n", .{name});
}

fn onMultitaskingViewDismissed(view_type: vd.MultitaskingViewType) void {
    const name = std.enums.tagName(vd.MultitaskingViewType, view_type) orelse "unnamed";

    std.debug.print("Dismissed: {s}\n", .{name});
}

const CALLBACK = vd.NotificationCallback{
    .onDesktopChanged = &onDesktopChanged,
    .onDesktopCreated = &onDesktopCreated,
    .onDesktopDestroyed = &onDesktopDestroyed,
    .onDesktopNameChanged = &onDesktopNameChanged,
    .onWindowDesktopChanged = &onWindowDesktopChanged,
    .onWindowEvent = &onWindowEvent,
    .onMultitaskingViewShown = &onMultitaskingViewShown,
    .onMultitaskingViewDismissed = &onMultitaskingViewDismissed,
};

pub fn main() !void {
    try vd.com.initialize(vd.com.COINIT_MULTITHREADED);
    defer vd.com.uninitialize();

    var service = try vd.Service.init();
    defer service.deinit();

    try service.registerNotification(&CALLBACK);

    std.debug.print("Listening for desktop events for 60 seconds...\n", .{});

    std.debug.print(
        "Try switching desktops, creating/removing desktops, renaming, Task View, Alt+Tab.\n",
        .{},
    );

    Sleep(60000);

    try service.unregisterNotification();
    std.debug.print("Done.\n", .{});
}
