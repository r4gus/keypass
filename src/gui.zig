const dvui = @import("dvui");
const application_state = @import("state.zig");
const main = @import("main.zig");

pub const login_frame = @import("gui/login.zig").login_frame;
pub const main_frame = @import("gui/main.zig").main_frame;
pub const info_dialog = @import("gui/info.zig").info_dialog;
pub const create_db_dialog = @import("gui/create.zig").create_db_dialog;
pub const database_security_dialog = @import("gui/database_security.zig").database_security_dialog;

pub var show_dialog: bool = false;
pub var show_create_dialog: bool = false;
pub var show_database_security_dialog: bool = false;

pub fn dvui_frame() !void {
    {
        var m = try dvui.menu(@src(), .horizontal, .{ .background = true, .expand = .horizontal });
        defer m.deinit();

        if (try dvui.menuItemLabel(@src(), "Database", .{ .submenu = true }, .{
            .expand = .none,
            .corner_radius = dvui.Rect.all(0),
        })) |r| {
            var fw = try dvui.popup(
                @src(),
                dvui.Rect.fromPoint(dvui.Point{ .x = r.x, .y = r.y + r.h }),
                .{
                    .corner_radius = dvui.Rect.all(0),
                },
            );
            defer fw.deinit();

            if (try dvui.menuItemLabel(@src(), "New Database...", .{}, .{
                .corner_radius = dvui.Rect.all(0),
            }) != null) {
                dvui.menuGet().?.close();
                show_create_dialog = true;
            }

            switch (application_state.app_state.getStateTag()) {
                .login => {},
                .main => {
                    if (try dvui.menuItemLabel(@src(), "Database Security", .{}, .{
                        .corner_radius = dvui.Rect.all(0),
                    }) != null) {
                        dvui.menuGet().?.close();
                        show_database_security_dialog = true;
                    }

                    if (try dvui.menuItemLabel(@src(), "Lock Database", .{}, .{
                        .corner_radius = dvui.Rect.all(0),
                    }) != null) {
                        dvui.menuGet().?.close();
                        application_state.deinit(main.gpa);
                    }
                },
            }
        }

        if (try dvui.menuItemLabel(@src(), "Help", .{ .submenu = true }, .{
            .expand = .none,
            .corner_radius = dvui.Rect.all(0),
        })) |r| {
            var fw = try dvui.popup(
                @src(),
                dvui.Rect.fromPoint(dvui.Point{ .x = r.x, .y = r.y + r.h }),
                .{
                    .corner_radius = dvui.Rect.all(0),
                },
            );
            defer fw.deinit();
            if (try dvui.menuItemLabel(@src(), "About", .{}, .{
                .corner_radius = dvui.Rect.all(0),
            }) != null) {
                dvui.menuGet().?.close();
                show_dialog = true;
            }
        }
    }

    var outer_box = try dvui.box(@src(), .vertical, .{
        .expand = .both,
        .color_style = .window,
        .background = true,
    });
    defer outer_box.deinit();

    switch (application_state.app_state.getStateTag()) {
        .login => try login_frame(),
        .main => try main_frame(),
    }

    if (show_dialog) {
        try info_dialog();
    }

    if (show_create_dialog) {
        try create_db_dialog();
    }

    if (show_database_security_dialog) {
        try database_security_dialog();
    }
}
