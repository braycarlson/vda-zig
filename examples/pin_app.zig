const std = @import("std");
const vd = @import("vd");

extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.winapi) void;

extern "user32" fn FindWindowW(?[*:0]const u16, ?[*:0]const u16) callconv(.winapi) isize;

fn findNotepad() isize {
    const class = comptime blk: {
        const s = "Notepad";
        var b: [s.len + 1]u16 = undefined;

        for (0..s.len) |i| b[i] = s[i];
        b[s.len] = 0;

        break :blk b;
    };

    return FindWindowW(@ptrCast(&class), null);
}

pub fn main() !void {
    try vd.com.initialize(vd.com.COINIT_MULTITHREADED);
    defer vd.com.uninitialize();

    var service = try vd.Service.init();
    defer service.deinit();

    const count = try service.getDesktopCount();
    const current = try service.getDesktopIndexCurrent();

    if (count < 2) {
        std.debug.print("Need at least 2 desktops.\n", .{});

        return;
    }

    const notepad = findNotepad();

    if (notepad == 0) {
        std.debug.print("Notepad must be running.\n", .{});

        return;
    }

    std.debug.print("App pinned before: {}\n", .{try service.isPinnedApp(notepad)});

    std.debug.print("Pinning app...\n", .{});
    try service.pinApp(notepad);
    std.debug.print("App pinned after: {}\n", .{try service.isPinnedApp(notepad)});

    const other: u32 = if (current == 0) 1 else 0;

    std.debug.print("Switching to desktop {d}...\n", .{other});
    try service.switchDesktop(other);
    Sleep(1000);

    std.debug.print("Switching back to {d}...\n", .{current});
    try service.switchDesktop(current);

    std.debug.print("Unpinning app...\n", .{});
    try service.unpinApp(notepad);
    std.debug.print("App pinned final: {}\n", .{try service.isPinnedApp(notepad)});
    Sleep(1000);
    std.debug.print("Done.\n", .{});
}
