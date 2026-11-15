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

    std.debug.print("Found notepad: 0x{x}\n", .{notepad});
    std.debug.print("On current desktop: {}\n", .{try service.isWindowOnCurrentDesktop(notepad)});

    std.debug.print("Moving to desktop 0...\n", .{});
    try service.moveWindowToDesktop(notepad, 0);
    std.debug.print("  Now on: {d}\n", .{try service.getWindowDesktopIndex(notepad)});
    Sleep(300);

    std.debug.print("Moving to desktop 1...\n", .{});
    try service.moveWindowToDesktop(notepad, 1);
    std.debug.print("  Now on: {d}\n", .{try service.getWindowDesktopIndex(notepad)});
    Sleep(300);

    std.debug.print("Moving back to desktop {d}...\n", .{current});
    try service.moveWindowToDesktop(notepad, current);
    std.debug.print("  Now on: {d}\n", .{try service.getWindowDesktopIndex(notepad)});
    std.debug.print("Done.\n", .{});
}
