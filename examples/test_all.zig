const std = @import("std");
const vd = @import("vd");

const assert = std.debug.assert;

extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.winapi) void;
extern "kernel32" fn LoadLibraryA([*:0]const u8) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn GetProcAddress(*anyopaque, [*:0]const u8) callconv(.winapi) ?*anyopaque;

extern "user32" fn FindWindowW(?[*:0]const u16, ?[*:0]const u16) callconv(.winapi) isize;

extern "user32" fn CreateWindowExW(
    u32,
    [*:0]const u16,
    [*:0]const u16,
    u32,
    i32,
    i32,
    i32,
    i32,
    isize,
    isize,
    ?*anyopaque,
    ?*anyopaque,
) callconv(.winapi) isize;

extern "user32" fn DestroyWindow(isize) callconv(.winapi) i32;
extern "user32" fn ShowWindow(isize, i32) callconv(.winapi) i32;
extern "user32" fn PeekMessageW(*Message, isize, u32, u32, u32) callconv(.winapi) i32;
extern "user32" fn TranslateMessage(*const Message) callconv(.winapi) i32;
extern "user32" fn DispatchMessageW(*const Message) callconv(.winapi) isize;

const Message = extern struct {
    hwnd: isize,
    message: u32,
    w_param: usize,
    l_param: isize,
    time: u32,
    point: [2]i32,
    private: u32,
};

const Events = struct {
    changed: u32 = 0,
    created: u32 = 0,
    destroyed: u32 = 0,
    renamed: u32 = 0,
    moved: u32 = 0,
    moved_from: u32 = 0,
    moved_to: u32 = 0,
    switched: u32 = 0,
    window_added: u32 = 0,
    window_removed: u32 = 0,
    window_handle: isize = 0,
    destroy_begin: u32 = 0,
    wallpaper: u32 = 0,
    window_desktop: u32 = 0,
    window_desktop_id: vd.GUID = vd.GUID.ZERO,
    window_desktop_watch: isize = 0,
    renamed_len: usize = 0,
    renamed_valid: bool = false,
};

const Suite = struct {
    service: *vd.Service,
    desktop_count: u32,
    desktop_original: u32,
    notepad: isize,
    passed: u32 = 0,
    failed: u32 = 0,
    skipped: u32 = 0,

    fn pass(suite: *Suite, name: []const u8) void {
        suite.passed += 1;

        std.debug.print("  [PASS] {s}\n", .{name});
    }

    fn fail(suite: *Suite, name: []const u8) void {
        suite.failed += 1;

        std.debug.print("  [FAIL] {s}\n", .{name});
    }

    fn skip(suite: *Suite, name: []const u8, reason: []const u8) void {
        suite.skipped += 1;

        std.debug.print("  [SKIP] {s} ({s})\n", .{ name, reason });
    }

    fn check(suite: *Suite, name: []const u8, ok: bool) void {
        if (ok) suite.pass(name) else suite.fail(name);
    }

    fn hasMultiple(suite: *const Suite) bool {
        return suite.desktop_count >= 2;
    }

    fn hasNotepad(suite: *const Suite) bool {
        return suite.notepad != 0;
    }
};

const WindowOptions = struct {
    title: [*:0]const u16,
    style: u32,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    parent: isize = 0,
};

const NOTIFICATION_CALLBACK = vd.NotificationCallback{
    .onDesktopChanged = &onChanged,
    .onDesktopCreated = &onCreated,
    .onDesktopDestroyBegin = &onDestroyBegin,
    .onDesktopDestroyed = &onDestroyed,
    .onDesktopNameChanged = &onRenamed,
    .onDesktopWallpaperChanged = &onWallpaperChanged,
    .onDesktopMoved = &onMoved,
    .onDesktopSwitched = &onSwitched,
    .onWindowDesktopChanged = &onWindowDesktopChanged,
    .onWindowEvent = &onWindowEvent,
};

const STYLE_CHILD_VISIBLE: u32 = 0x50000000;
const STYLE_OVERLAPPED_WINDOW: u32 = 0x00CF0000;
const WALLPAPER_PATH = "C:\\Windows\\Web\\Wallpaper\\Windows\\img0.jpg";

var events: Events = .{};

fn onChanged(_: vd.GUID, _: vd.GUID) void {
    _ = @atomicRmw(u32, &events.changed, .Add, 1, .monotonic);
}

fn onCreated(_: vd.GUID) void {
    _ = @atomicRmw(u32, &events.created, .Add, 1, .monotonic);
}

fn onDestroyed(_: vd.GUID, _: vd.GUID) void {
    _ = @atomicRmw(u32, &events.destroyed, .Add, 1, .monotonic);
}

fn onRenamed(_: vd.GUID, name: []const u8) void {
    events.renamed_len = name.len;
    events.renamed_valid = std.unicode.utf8ValidateSlice(name);

    _ = @atomicRmw(u32, &events.renamed, .Add, 1, .release);
}

fn onMoved(_: vd.GUID, from: u32, to: u32) void {
    @atomicStore(u32, &events.moved_from, from, .monotonic);
    @atomicStore(u32, &events.moved_to, to, .monotonic);
    _ = @atomicRmw(u32, &events.moved, .Add, 1, .monotonic);
}

fn onSwitched(_: vd.GUID, _: u32) void {
    _ = @atomicRmw(u32, &events.switched, .Add, 1, .monotonic);
}

fn onWindowEvent(handle: isize, change: vd.ApplicationViewChange) void {
    if (handle == 0) return;
    if (handle != @atomicLoad(isize, &events.window_handle, .monotonic)) return;

    switch (change) {
        .added => _ = @atomicRmw(u32, &events.window_added, .Add, 1, .monotonic),
        .removed => _ = @atomicRmw(u32, &events.window_removed, .Add, 1, .monotonic),
        else => {},
    }
}

fn onDestroyBegin(_: vd.GUID, _: vd.GUID) void {
    _ = @atomicRmw(u32, &events.destroy_begin, .Add, 1, .monotonic);
}

fn onWallpaperChanged(_: vd.GUID, path: []const u8) void {
    if (path.len == 0) return;

    _ = @atomicRmw(u32, &events.wallpaper, .Add, 1, .monotonic);
}

fn onWindowDesktopChanged(handle: isize, desktop: vd.GUID) void {
    if (handle != @atomicLoad(isize, &events.window_desktop_watch, .monotonic)) return;

    events.window_desktop_id = desktop;

    _ = @atomicRmw(u32, &events.window_desktop, .Add, 1, .release);
}

fn attempt(step: []const u8, result: anytype) void {
    comptime assert(@typeInfo(@TypeOf(result)) == .error_union);

    if (result) |_| {} else |err| {
        std.debug.print("  [WARN] {s} failed: {s}\n", .{ step, @errorName(err) });
    }
}

fn createWindow(options: WindowOptions) isize {
    return CreateWindowExW(
        0,
        std.unicode.utf8ToUtf16LeStringLiteral("STATIC"),
        options.title,
        options.style,
        options.x,
        options.y,
        options.width,
        options.height,
        options.parent,
        0,
        null,
        null,
    );
}

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

fn sleep(ms: u64) void {
    Sleep(@intCast(ms));
}

fn pumpMessages(ms: u32) void {
    var waited: u32 = 0;

    while (waited < ms) : (waited += 50) {
        var message: Message = undefined;

        while (PeekMessageW(&message, 0, 0, 0, 1) != 0) {
            _ = TranslateMessage(&message);
            _ = DispatchMessageW(&message);
        }

        Sleep(50);
    }
}

fn testQueries(suite: *Suite) void {
    const service = suite.service;
    const count = suite.desktop_count;

    suite.check("is_connected", service.isConnected());
    suite.check("desktop_count", count > 0);
    suite.check("current_desktop_in_range", suite.desktop_original < count);

    if (service.getDesktops()) |result| {
        suite.check("get_desktops_count", result.count == count);

        if (result.count > 0) {
            suite.check("get_desktops_first_index", result.items[0].index == 0);
        }
    } else |_| {
        suite.fail("get_desktops_count");
        suite.fail("get_desktops_first_index");
    }

    if (service.getDesktopGuid(0)) |id| {
        suite.pass("get_desktop_guid");

        if (service.getDesktopIndexByGuid(&id)) |idx| {
            suite.check("guid_index_roundtrip", idx == 0);
        } else |_| {
            suite.fail("guid_index_roundtrip");
        }
    } else |_| {
        suite.fail("get_desktop_guid");
        suite.fail("guid_index_roundtrip");
    }

    var buf: [vd.NAME_LEN_MAX]u8 = undefined;

    if (service.getDesktopName(0, &buf)) |_| {
        suite.pass("get_desktop_name");
    } else |_| {
        suite.fail("get_desktop_name");
    }

    if (service.getDesktopWallpaper(0, &buf)) |_| {
        suite.pass("get_desktop_wallpaper");
    } else |_| {
        suite.fail("get_desktop_wallpaper");
    }

    if (service.isDesktopRemote(0)) |remote| {
        suite.check("desktop_not_remote", !remote);
    } else |_| {
        suite.fail("desktop_not_remote");
    }

    if (service.getVisibleMultitaskingViews()) |views| {
        suite.check("no_multitasking_view_visible", views == 0);
    } else |_| {
        suite.fail("no_multitasking_view_visible");
    }
}

fn testSwitch(suite: *Suite) void {
    const service = suite.service;
    const original = suite.desktop_original;
    const target: u32 = if (original == 0) 1 else 0;

    if (service.switchDesktop(target)) {
        const current = service.getDesktopIndexCurrent() catch 999;

        suite.check("switch_desktop", current == target);
        attempt("restore the original desktop", service.switchDesktop(original));
        sleep(200);
    } else |_| {
        suite.fail("switch_desktop");
    }

    testAdjacent(suite);
    testAnimatedSwitch(suite);
}

fn testAdjacent(suite: *Suite) void {
    const service = suite.service;

    if (service.getAdjacentDesktopIndex(0, .right)) |index| {
        suite.check("adjacent_right", index == 1);
    } else |_| {
        suite.fail("adjacent_right");
    }

    if (service.getAdjacentDesktopIndex(1, .backward)) |index| {
        suite.check("adjacent_backward", index == 0);
    } else |_| {
        suite.fail("adjacent_backward");
    }

    if (service.getAdjacentDesktopIndex(0, .left)) |_| {
        suite.fail("adjacent_left_edge");
    } else |err| {
        suite.check("adjacent_left_edge", err == vd.Error.DesktopNotFound);
    }
}

fn testAnimatedSwitch(suite: *Suite) void {
    const service = suite.service;
    const original = suite.desktop_original;
    const target: u32 = if (original == 0) 1 else 0;

    if (service.switchDesktopWithAnimation(target)) {
        const current = service.getDesktopIndexCurrent() catch 999;

        suite.check("switch_desktop_with_animation", current == target);
    } else |_| {
        suite.fail("switch_desktop_with_animation");
    }

    if (service.waitForAnimationToComplete()) {
        suite.pass("wait_for_animation_to_complete");
    } else |_| {
        suite.fail("wait_for_animation_to_complete");
    }

    if (service.getDesktopIndexLastActive()) |last| {
        suite.check("last_active_desktop", last == original);
    } else |_| {
        suite.fail("last_active_desktop");
    }

    attempt("restore the original desktop", service.switchDesktop(original));
    sleep(200);
}

fn testSetName(suite: *Suite) void {
    const service = suite.service;

    var buf: [vd.NAME_LEN_MAX]u8 = undefined;
    const original_name = service.getDesktopName(0, &buf) catch "";
    var saved: [vd.NAME_LEN_MAX]u8 = undefined;
    const saved_len = original_name.len;

    @memcpy(saved[0..saved_len], original_name);

    if (service.setDesktopName(0, "vda_zig_test")) {
        var buf2: [vd.NAME_LEN_MAX]u8 = undefined;
        const renamed_name = service.getDesktopName(0, &buf2) catch "";

        suite.check("set_desktop_name", std.mem.eql(u8, renamed_name, "vda_zig_test"));
        attempt("restore the desktop name", service.setDesktopName(0, saved[0..saved_len]));
    } else |_| {
        suite.fail("set_desktop_name");
    }
}

fn testDesktopNames(suite: *Suite) void {
    const service = suite.service;

    var buf: [vd.NAME_LEN_MAX]u8 = undefined;
    var saved: [vd.NAME_LEN_MAX]u8 = undefined;
    const original = service.getDesktopName(0, &buf) catch "";

    @memcpy(saved[0..original.len], original);

    const saved_name = saved[0..original.len];
    const long_name: [300]u8 = @splat('x');

    attempt("set a 300 character name", service.setDesktopName(0, &long_name));

    const long_read = service.getDesktopName(0, &buf) catch "";

    suite.check("desktop_name_300_chars", std.mem.eql(u8, long_read, &long_name));

    const unicode_name = "B\u{fc}r\u{f6} \u{2713} \u{6771}\u{4eac}";

    attempt("set a unicode name", service.setDesktopName(0, unicode_name));

    const unicode_read = service.getDesktopName(0, &buf) catch "";

    suite.check("desktop_name_unicode", std.mem.eql(u8, unicode_read, unicode_name));

    const longest: [vd.NAME_LEN_MAX]u8 = @splat('y');

    attempt("set the longest name", service.setDesktopName(0, &longest));

    const longest_read = service.getDesktopName(0, &buf) catch "";

    suite.check("desktop_name_limit", std.mem.eql(u8, longest_read, &longest));

    const too_long: [vd.NAME_LEN_MAX + 1]u8 = @splat('x');

    if (service.setDesktopName(0, &too_long)) |_| {
        suite.fail("desktop_name_too_long");
    } else |err| {
        suite.check("desktop_name_too_long", err == vd.Error.StringTooLong);
    }

    if (service.setDesktopName(0, "\xff\xfe")) |_| {
        suite.fail("desktop_name_invalid_utf8");
    } else |err| {
        suite.check("desktop_name_invalid_utf8", err == vd.Error.InvalidArgument);
    }

    attempt("restore the desktop name", service.setDesktopName(0, saved_name));
}

fn testCreateRemove(suite: *Suite) void {
    const service = suite.service;
    const count = suite.desktop_count;

    if (service.createDesktop()) |created_index| {
        suite.pass("create_desktop");

        const desktop_count_created = service.getDesktopCount() catch 0;

        suite.check("create_desktop_count", desktop_count_created == count + 1);

        if (service.removeDesktop(created_index, 0)) {
            suite.pass("remove_desktop");

            const desktop_count_final = service.getDesktopCount() catch 0;

            suite.check("remove_desktop_count", desktop_count_final == count);
        } else |_| {
            suite.fail("remove_desktop");
            suite.fail("remove_desktop_count");
        }
    } else |_| {
        suite.fail("create_desktop");
        suite.skip("create_desktop_count", "create failed");
        suite.skip("remove_desktop", "create failed");
        suite.skip("remove_desktop_count", "create failed");
    }
}

fn testDesktopLimit(suite: *Suite) void {
    const service = suite.service;

    var created: [vd.DESKTOPS_MAX + 1]vd.GUID = undefined;
    var created_count: usize = 0;

    while (created_count < created.len) {
        const count = service.getDesktopCount() catch break;
        if (count > vd.DESKTOPS_MAX) break;

        const desktop = service.manager_internal.createDesktop() catch break;

        created[created_count] = desktop.getId() catch vd.GUID.ZERO;
        created_count += 1;

        vd.com.releaseObj(desktop);
    }

    if (service.getDesktops()) |_| {
        suite.fail("get_desktops_over_limit");
    } else |err| {
        suite.check("get_desktops_over_limit", err == vd.Error.DesktopLimitReached);
    }

    if (service.createDesktop()) |index| {
        suite.fail("create_desktop_over_limit");
        attempt("remove the desktop over the limit", service.removeDesktop(index, 0));
    } else |err| {
        suite.check("create_desktop_over_limit", err == vd.Error.DesktopLimitReached);
    }

    for (created[0..created_count]) |id| {
        const index = service.getDesktopIndexByGuid(&id) catch continue;

        attempt("remove a desktop created for the limit", service.removeDesktop(index, 0));
    }
}

fn testWindowQueries(suite: *Suite) void {
    const service = suite.service;
    const notepad = suite.notepad;
    const original = suite.desktop_original;

    if (service.getWindowDesktopIndex(notepad)) |win_idx| {
        suite.pass("get_window_desktop_index");
        suite.check("window_on_valid_desktop", win_idx < suite.desktop_count);
    } else |_| {
        suite.fail("get_window_desktop_index");
        suite.fail("window_on_valid_desktop");
    }

    if (service.getWindowDesktopGuid(notepad)) |_| {
        suite.pass("get_window_desktop_guid");
    } else |_| {
        suite.fail("get_window_desktop_guid");
    }

    if (service.isWindowOnCurrentDesktop(notepad)) |_| {
        suite.pass("is_window_on_current_desktop");
    } else |_| {
        suite.fail("is_window_on_current_desktop");
    }

    const notepad_desktop = service.getWindowDesktopIndex(notepad) catch original;

    if (service.isWindowOnDesktop(notepad, notepad_desktop)) |on_desktop| {
        suite.check("is_window_on_desktop", on_desktop);
    } else |_| {
        suite.fail("is_window_on_desktop");
    }

    const target: u32 = if (original == 0) 1 else 0;

    if (service.moveWindowToDesktop(notepad, target)) {
        const win_idx = service.getWindowDesktopIndex(notepad) catch 999;

        suite.check("move_window_to_desktop", win_idx == target);
        attempt("move notepad back", service.moveWindowToDesktop(notepad, original));
        sleep(200);
    } else |_| {
        suite.fail("move_window_to_desktop");
    }
}

fn skipWindowQueries(suite: *Suite, reason: []const u8) void {
    suite.skip("get_window_desktop_index", reason);
    suite.skip("window_on_valid_desktop", reason);
    suite.skip("get_window_desktop_guid", reason);
    suite.skip("is_window_on_current_desktop", reason);
    suite.skip("is_window_on_desktop", reason);
    suite.skip("move_window_to_desktop", reason);
}

fn testOwnedWindows(suite: *Suite) void {
    const service = suite.service;
    const original = suite.desktop_original;

    const owner = createWindow(.{
        .title = std.unicode.utf8ToUtf16LeStringLiteral("vda_zig_owner"),
        .style = STYLE_OVERLAPPED_WINDOW,
        .x = 100,
        .y = 100,
        .width = 300,
        .height = 200,
    });

    defer _ = DestroyWindow(owner);

    const owned = createWindow(.{
        .title = std.unicode.utf8ToUtf16LeStringLiteral("vda_zig_owned"),
        .style = STYLE_OVERLAPPED_WINDOW,
        .x = 150,
        .y = 150,
        .width = 300,
        .height = 200,
        .parent = owner,
    });

    const child = createWindow(.{
        .title = std.unicode.utf8ToUtf16LeStringLiteral("vda_zig_child"),
        .style = STYLE_CHILD_VISIBLE,
        .x = 10,
        .y = 10,
        .width = 100,
        .height = 50,
        .parent = owned,
    });

    for ([_]isize{ owner, owned, child }) |window| {
        if (window == 0) return skipOwnedWindows(suite, "CreateWindowExW failed");
    }

    _ = ShowWindow(owner, 5);
    _ = ShowWindow(owned, 5);

    pumpMessages(1000);

    const owner_index = service.getWindowDesktopIndex(owner) catch 999;
    const owned_index = service.getWindowDesktopIndex(owned) catch 998;
    const child_index = service.getWindowDesktopIndex(child) catch 997;

    suite.check("owned_window_index", owned_index == owner_index);
    suite.check("child_window_index", child_index == owner_index);

    const target: u32 = if (original == 0) 1 else 0;

    attempt("move the owned window", service.moveWindowToDesktop(owned, target));
    pumpMessages(500);

    const moved_index = service.getWindowDesktopIndex(owner) catch 999;

    suite.check("owned_window_moves_owner", moved_index == target);

    const on_current = service.isWindowOnCurrentDesktop(owned) catch true;
    const on_target = service.isWindowOnDesktop(owned, target) catch false;
    const on_original = service.isWindowOnDesktop(owned, original) catch true;

    suite.check("owned_window_follows_owner", !on_current and on_target and !on_original);
}

fn skipOwnedWindows(suite: *Suite, reason: []const u8) void {
    suite.skip("owned_window_index", reason);
    suite.skip("child_window_index", reason);
    suite.skip("owned_window_moves_owner", reason);
    suite.skip("owned_window_follows_owner", reason);
}

fn testPinWindow(suite: *Suite) void {
    const service = suite.service;
    const notepad = suite.notepad;
    const was_pinned = service.isPinnedWindow(notepad) catch true;

    if (was_pinned) {
        suite.skip("pin_window", "already pinned");
        suite.skip("unpin_window", "already pinned");

        return;
    }

    if (service.pinWindow(notepad)) {
        const is_pinned = service.isPinnedWindow(notepad) catch false;

        suite.check("pin_window", is_pinned);

        if (service.getWindowDesktopIndex(notepad)) |_| {
            suite.fail("pinned_window_index");
        } else |err| {
            suite.check("pinned_window_index", err == vd.Error.WindowPinned);
        }

        if (service.getWindowDesktopGuid(notepad)) |id| {
            suite.check("pinned_window_guid", id.eql(vd.guid.DESKTOP_ID_PINNED_VIEW));
        } else |_| {
            suite.fail("pinned_window_guid");
        }

        if (suite.hasMultiple()) {
            const on_first = service.isWindowOnDesktop(notepad, 0) catch false;
            const on_second = service.isWindowOnDesktop(notepad, 1) catch false;

            suite.check("pinned_window_on_every_desktop", on_first and on_second);
        }

        attempt("unpin notepad", service.unpinWindow(notepad));

        const after_unpin = service.isPinnedWindow(notepad) catch true;

        suite.check("unpin_window", !after_unpin);
    } else |_| {
        suite.fail("pin_window");
        suite.skip("unpin_window", "pin failed");
    }
}

fn testPinApp(suite: *Suite) void {
    const service = suite.service;
    const notepad = suite.notepad;
    const was_pinned = service.isPinnedApp(notepad) catch true;

    if (was_pinned) {
        suite.skip("pin_app", "already pinned");
        suite.skip("unpin_app", "already pinned");

        return;
    }

    if (service.pinApp(notepad)) {
        const is_pinned = service.isPinnedApp(notepad) catch false;

        suite.check("pin_app", is_pinned);
        attempt("unpin the notepad app", service.unpinApp(notepad));

        const after_unpin = service.isPinnedApp(notepad) catch true;

        suite.check("unpin_app", !after_unpin);
    } else |_| {
        suite.fail("pin_app");
        suite.skip("unpin_app", "pin failed");
    }
}

fn testErrors(suite: *Suite) void {
    const service = suite.service;

    if (service.getWindowDesktopIndex(9999999)) |_| {
        suite.fail("error_invalid_hwnd");
    } else |err| {
        suite.check("error_invalid_hwnd", err == vd.Error.WindowNotFound);
    }

    if (service.switchDesktop(99999)) |_| {
        suite.fail("error_invalid_desktop");
    } else |err| {
        suite.check("error_invalid_desktop", err == vd.Error.DesktopNotFound);
    }

    if (service.moveWindowToDesktop(9999999, 0)) |_| {
        suite.fail("error_move_invalid_hwnd");
    } else |err| {
        suite.check("error_move_invalid_hwnd", err == vd.Error.WindowNotFound);
    }

    if (suite.hasNotepad()) {
        if (service.moveWindowToDesktop(suite.notepad, 99999)) |_| {
            suite.fail("error_move_invalid_desktop");
        } else |err| {
            suite.check("error_move_invalid_desktop", err == vd.Error.DesktopNotFound);
        }
    } else {
        suite.skip("error_move_invalid_desktop", "notepad not running");
    }
}

fn testNotifications(suite: *Suite) void {
    const service = suite.service;
    const original = suite.desktop_original;

    @atomicStore(u32, &events.changed, 0, .monotonic);
    @atomicStore(u32, &events.created, 0, .monotonic);
    @atomicStore(u32, &events.destroyed, 0, .monotonic);
    @atomicStore(u32, &events.renamed, 0, .monotonic);

    if (service.registerNotification(&NOTIFICATION_CALLBACK)) {
        sleep(100);

        const target: u32 = if (original == 0) 1 else 0;

        attempt("switch to the target desktop", service.switchDesktop(target));
        sleep(200);
        attempt("switch back to the original desktop", service.switchDesktop(original));
        sleep(200);
        exerciseDesktopEvents(service);

        testMoveDesktop(suite);
        testWindowEvents(suite);
        testWallpaperAndRemoval(suite);
        testLongNameEvent(suite);

        if (suite.hasNotepad()) {
            testWindowDesktopEvents(suite);
        } else {
            suite.skip("notify_window_desktop_changed", "notepad not running");
            suite.skip("notify_window_pinned", "notepad not running");
        }

        attempt("unregister notifications", service.unregisterNotification());
        checkNotifications(suite);
    } else |_| {
        suite.fail("register_notification");
        skipNotifications(suite, "registration failed");
    }
}

fn exerciseDesktopEvents(service: *vd.Service) void {
    if (service.createDesktop()) |created_index| {
        sleep(200);
        attempt("name the created desktop", service.setDesktopName(created_index, "notify_test"));
        sleep(200);
        attempt("remove the created desktop", service.removeDesktop(created_index, 0));
        sleep(200);
    } else |err| {
        std.debug.print("  [WARN] create a desktop failed: {s}\n", .{@errorName(err)});
    }
}

fn checkNotifications(suite: *Suite) void {
    const changed = @atomicLoad(u32, &events.changed, .monotonic);
    const created = @atomicLoad(u32, &events.created, .monotonic);
    const destroyed = @atomicLoad(u32, &events.destroyed, .monotonic);
    const renamed = @atomicLoad(u32, &events.renamed, .monotonic);
    const switched = @atomicLoad(u32, &events.switched, .monotonic);

    suite.check("notify_desktop_changed", changed >= 2);
    suite.check("notify_desktop_created", created >= 1);
    suite.check("notify_desktop_destroyed", destroyed >= 1);
    suite.check("notify_desktop_renamed", renamed >= 1);
    suite.check("notify_desktop_switched", switched >= 2);
}

fn skipNotifications(suite: *Suite, reason: []const u8) void {
    suite.skip("notify_desktop_changed", reason);
    suite.skip("notify_desktop_created", reason);
    suite.skip("notify_desktop_destroyed", reason);
    suite.skip("notify_desktop_renamed", reason);
    suite.skip("notify_desktop_switched", reason);
}

fn testMoveDesktop(suite: *Suite) void {
    const service = suite.service;

    const index = service.createDesktop() catch {
        suite.fail("move_desktop");
        suite.skip("notify_desktop_moved", "create failed");

        return;
    };

    const id = service.getDesktopGuid(index) catch vd.GUID.ZERO;

    sleep(200);

    if (service.moveDesktop(index, 0)) {
        sleep(300);

        const first = service.getDesktopGuid(0) catch vd.GUID.ZERO;
        const from = @atomicLoad(u32, &events.moved_from, .monotonic);
        const to = @atomicLoad(u32, &events.moved_to, .monotonic);

        suite.check("move_desktop", first.eql(id));
        suite.check("notify_desktop_moved", from == index and to == 0);

        if (service.moveDesktop(0, 0)) {
            const still_first = service.getDesktopGuid(0) catch vd.GUID.ZERO;

            suite.check("move_desktop_same_index", still_first.eql(id));
        } else |_| {
            suite.fail("move_desktop_same_index");
        }
    } else |_| {
        suite.fail("move_desktop");
        suite.skip("notify_desktop_moved", "move failed");
    }

    const moved_index = service.getDesktopIndexByGuid(&id) catch index;
    const fallback_index: u32 = if (moved_index == 0) 1 else 0;

    attempt("remove the moved desktop", service.removeDesktop(moved_index, fallback_index));
    sleep(200);
}

fn testWindowEvents(suite: *Suite) void {
    const handle = createWindow(.{
        .title = std.unicode.utf8ToUtf16LeStringLiteral("vda_zig_test"),
        .style = STYLE_OVERLAPPED_WINDOW,
        .x = 100,
        .y = 100,
        .width = 300,
        .height = 200,
    });

    if (handle == 0) {
        suite.skip("notify_window_added", "CreateWindowExW failed");
        suite.skip("notify_window_removed", "CreateWindowExW failed");

        return;
    }

    @atomicStore(isize, &events.window_handle, handle, .monotonic);
    _ = ShowWindow(handle, 5);

    pumpMessages(1500);

    const added = @atomicLoad(u32, &events.window_added, .monotonic);

    suite.check("notify_window_added", added >= 1);

    _ = DestroyWindow(handle);

    pumpMessages(1500);

    const removed = @atomicLoad(u32, &events.window_removed, .monotonic);

    suite.check("notify_window_removed", removed >= 1);
}

fn testWallpaperAndRemoval(suite: *Suite) void {
    const service = suite.service;

    const index = service.createDesktop() catch {
        suite.fail("notify_desktop_wallpaper_changed");
        suite.skip("remove_desktop_self_fallback", "create failed");
        suite.skip("notify_desktop_destroy_begin", "create failed");

        return;
    };

    sleep(200);
    attempt("set the desktop wallpaper", service.setDesktopWallpaper(index, WALLPAPER_PATH));
    sleep(500);

    const wallpapers = @atomicLoad(u32, &events.wallpaper, .monotonic);

    suite.check("notify_desktop_wallpaper_changed", wallpapers >= 1);

    if (service.removeDesktop(index, index)) |_| {
        suite.fail("remove_desktop_self_fallback");
    } else |err| {
        suite.check("remove_desktop_self_fallback", err == vd.Error.InvalidArgument);
    }

    attempt("remove the wallpaper desktop", service.removeDesktop(index, 0));
    sleep(300);

    const destroy_begins = @atomicLoad(u32, &events.destroy_begin, .monotonic);

    suite.check("notify_desktop_destroy_begin", destroy_begins >= 1);
}

fn testLongNameEvent(suite: *Suite) void {
    const service = suite.service;
    const name_test = "notify_desktop_renamed_truncated";

    const combase = LoadLibraryA("combase.dll") orelse {
        return suite.skip(name_test, "combase not loaded");
    };

    const create_string = GetProcAddress(combase, "WindowsCreateString") orelse {
        return suite.skip(name_test, "no WindowsCreateString");
    };

    const create: *const fn (
        [*]const u16,
        u32,
        *vd.HSTRING,
    ) callconv(.winapi) vd.HRESULT = @ptrCast(create_string);

    const wide: [vd.NAME_LEN_MAX / 3 + 76]u16 = @splat(0x6771);
    var name: vd.HSTRING = null;

    _ = create(&wide, wide.len, &name);
    defer vd.com.deleteHString(name);

    var buf: [vd.NAME_LEN_MAX]u8 = undefined;
    var saved: [vd.NAME_LEN_MAX]u8 = undefined;
    const original = service.getDesktopName(0, &buf) catch "";

    @memcpy(saved[0..original.len], original);

    const saved_name = saved[0..original.len];
    const id = service.getDesktopGuid(0) catch vd.GUID.ZERO;
    const desktop = service.manager_internal.findDesktop(&id) catch return suite.fail(name_test);
    defer vd.com.releaseObj(desktop);

    const seen = @atomicLoad(u32, &events.renamed, .acquire);

    attempt("set the long name", service.manager_internal.setName(desktop, name));
    sleep(500);

    const fired = @atomicLoad(u32, &events.renamed, .acquire) > seen;
    const truncated = events.renamed_len == vd.NAME_LEN_MAX;

    suite.check(name_test, fired and truncated and events.renamed_valid);

    if (service.getDesktopName(0, &buf)) |_| {
        suite.fail("desktop_name_over_limit");
    } else |err| {
        suite.check("desktop_name_over_limit", err == vd.Error.StringTooLong);
    }

    attempt("restore the desktop name", service.setDesktopName(0, saved_name));
}

fn testWindowDesktopEvents(suite: *Suite) void {
    const service = suite.service;
    const notepad = suite.notepad;
    const original = suite.desktop_original;
    const target: u32 = if (original == 0) 1 else 0;
    const target_id = service.getDesktopGuid(target) catch vd.GUID.ZERO;

    @atomicStore(isize, &events.window_desktop_watch, notepad, .monotonic);

    var seen = @atomicLoad(u32, &events.window_desktop, .acquire);

    attempt("move notepad to the target desktop", service.moveWindowToDesktop(notepad, target));
    sleep(500);

    const moved = @atomicLoad(u32, &events.window_desktop, .acquire) > seen;
    const moved_target = events.window_desktop_id.eql(target_id);

    suite.check("notify_window_desktop_changed", moved and moved_target);

    seen = @atomicLoad(u32, &events.window_desktop, .acquire);

    attempt("pin notepad", service.pinWindow(notepad));
    sleep(500);

    const pinned = @atomicLoad(u32, &events.window_desktop, .acquire) > seen;
    const pinned_view = events.window_desktop_id.eql(vd.guid.DESKTOP_ID_PINNED_VIEW);

    suite.check("notify_window_pinned", pinned and pinned_view);

    attempt("unpin notepad", service.unpinWindow(notepad));
    attempt("move notepad back", service.moveWindowToDesktop(notepad, original));
    sleep(300);
}

fn testReconnect(suite: *Suite) void {
    const service = suite.service;

    if (service.reconnect()) {
        suite.pass("reconnect");

        const still_works = service.getDesktopCount() catch 0;

        suite.check("reconnect_still_works", still_works > 0);
    } else |_| {
        suite.fail("reconnect");
        suite.skip("reconnect_still_works", "reconnect failed");
    }
}

fn removeTemporaryDesktop(service: *vd.Service, desktop_count_initial: u32) void {
    const count = service.getDesktopCount() catch 0;
    if (count <= desktop_count_initial) return;

    attempt("remove the temporary desktop", service.removeDesktop(count - 1, 0));
}

pub fn main() !void {
    try vd.com.initialize(vd.com.COINIT_MULTITHREADED);
    defer vd.com.uninitialize();

    var service = try vd.Service.init();
    defer service.deinit();

    const original_desktop = try service.getDesktopIndexCurrent();
    const desktop_count_initial = try service.getDesktopCount();
    const notepad = findNotepad();

    var created_temp_desktop = false;

    if (desktop_count_initial < 2) {
        attempt("create a temporary desktop", service.createDesktop());
        created_temp_desktop = (service.getDesktopCount() catch 0) >= 2;
    }

    defer if (created_temp_desktop) removeTemporaryDesktop(&service, desktop_count_initial);

    var suite: Suite = .{
        .service = &service,
        .desktop_count = try service.getDesktopCount(),
        .desktop_original = original_desktop,
        .notepad = notepad,
    };

    std.debug.print("\n=== vda-zig Automated Test Suite ===\n\n", .{});

    std.debug.print("  Desktops: {d}{s}, Current: {d}, Notepad: {s}\n\n", .{
        suite.desktop_count,
        if (created_temp_desktop) " (1 temporary)" else "",
        original_desktop,
        if (suite.hasNotepad()) "found" else "not found",
    });

    runSuite(&suite);

    const total = suite.passed + suite.failed;

    std.debug.print("\n=== Results: {d}/{d} passed", .{ suite.passed, total });
    if (suite.skipped > 0) std.debug.print(", {d} skipped", .{suite.skipped});
    std.debug.print(" ===\n\n", .{});

    if (suite.failed > 0) std.process.exit(1);
}

fn runSuite(suite: *Suite) void {
    testQueries(suite);

    if (suite.hasMultiple()) {
        testSwitch(suite);
    } else {
        suite.skip("switch_desktop", "need 2+ desktops");
    }

    testSetName(suite);
    testDesktopNames(suite);
    testCreateRemove(suite);
    testDesktopLimit(suite);

    if (suite.hasNotepad()) {
        if (suite.hasMultiple()) {
            testWindowQueries(suite);
        } else {
            skipWindowQueries(suite, "need 2+ desktops");
        }
    } else {
        skipWindowQueries(suite, "notepad not running");
    }

    if (suite.hasMultiple()) {
        testOwnedWindows(suite);
    } else {
        skipOwnedWindows(suite, "need 2+ desktops");
    }

    if (suite.hasNotepad()) {
        testPinWindow(suite);
        testPinApp(suite);
    } else {
        suite.skip("pin_window", "notepad not running");
        suite.skip("unpin_window", "notepad not running");
        suite.skip("pin_app", "notepad not running");
        suite.skip("unpin_app", "notepad not running");
    }

    testErrors(suite);

    if (suite.hasMultiple()) {
        testNotifications(suite);
    } else {
        skipNotifications(suite, "need 2+ desktops");
    }

    testReconnect(suite);
}
