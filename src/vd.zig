const visibility_notification = @import("i_multitasking_view_visibility_notification.zig");

pub const com = @import("com.zig");
pub const guid = @import("guid.zig");

pub const IServiceProvider = @import("i_service_provider.zig").IServiceProvider;
pub const IObjectArray = @import("i_object_array.zig").IObjectArray;
pub const IVirtualDesktop = @import("i_virtual_desktop.zig").IVirtualDesktop;
pub const IVirtualDesktop2 = @import("i_virtual_desktop2.zig").IVirtualDesktop2;
pub const IApplicationView = @import("i_application_view.zig").IApplicationView;
pub const IVirtualDesktopManager = @import("i_virtual_desktop_manager.zig").IVirtualDesktopManager;

pub const IVirtualDesktopManagerInternal2 =
    @import("i_virtual_desktop_manager_internal2.zig").IVirtualDesktopManagerInternal2;

pub const AdjacentDirection = @import("i_virtual_desktop_manager_internal2.zig").AdjacentDirection;

pub const IApplicationViewCollection =
    @import("i_application_view_collection.zig").IApplicationViewCollection;

pub const ApplicationViewChangeListener =
    @import("i_application_view_change_listener.zig").ApplicationViewChangeListener;

pub const ApplicationViewChange =
    @import("i_application_view_change_listener.zig").ApplicationViewChange;

pub const IVirtualDesktopPinnedApps =
    @import("i_virtual_desktop_pinned_apps.zig").IVirtualDesktopPinnedApps;

pub const IVirtualDesktopNotificationService =
    @import("i_virtual_desktop_notification_service.zig").IVirtualDesktopNotificationService;

pub const VirtualDesktopNotification =
    @import("i_virtual_desktop_notification.zig").VirtualDesktopNotification;

pub const NotificationCallback = @import("i_virtual_desktop_notification.zig").NotificationCallback;

pub const IMultitaskingViewVisibilityService =
    @import("i_multitasking_view_visibility_service.zig").IMultitaskingViewVisibilityService;

pub const MultitaskingViewType =
    @import("i_multitasking_view_visibility_service.zig").MultitaskingViewType;

pub const MultitaskingViewVisibilityNotification =
    visibility_notification.MultitaskingViewVisibilityNotification;

pub const Service = @import("service.zig").Service;
pub const DesktopInfo = @import("service.zig").DesktopInfo;
pub const DesktopsResult = @import("service.zig").DesktopsResult;

pub const GUID = guid.GUID;
pub const HRESULT = i32;
pub const HSTRING = com.HSTRING;
pub const DESKTOPS_MAX = @import("service.zig").DESKTOPS_MAX;
pub const NAME_LEN_MAX = @import("service.zig").NAME_LEN_MAX;

pub const Error = error{
    ComInitFailed,
    ComCreateFailed,
    ComCallFailed,
    ServiceNotConnected,
    DesktopNotFound,
    WindowNotFound,
    DesktopLimitReached,
    StringTooLong,
    NullPointer,
    AccessDenied,
    InvalidArgument,
    InvalidState,
    WindowPinned,
};

pub fn hresultToError(hr: HRESULT) Error!void {
    if (hr >= 0) return;

    return switch (@as(u32, @bitCast(hr))) {
        0x80040154 => Error.ServiceNotConnected,
        0x800706BA => Error.ServiceNotConnected,
        0x800401FD => Error.ServiceNotConnected,
        0x80010108 => Error.ServiceNotConnected,
        0x800401F0 => Error.ComInitFailed,
        0x8002802B => Error.DesktopNotFound,
        0x80028CA1 => Error.DesktopNotFound,
        0x80070005 => Error.AccessDenied,
        0x80070057 => Error.InvalidArgument,
        0x800706F4 => Error.InvalidArgument,
        0x8007139F => Error.InvalidState,
        else => Error.ComCallFailed,
    };
}
