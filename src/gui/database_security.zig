const std = @import("std");
const dvui = @import("dvui");
const main = @import("../main.zig");
const tresor = @import("tresor");
const db = @import("../db.zig");
const gui = @import("../gui.zig");
const create = @import("create.zig");
const application_state = @import("../state.zig");

/// Dialog for updating a existing database
pub fn database_security_dialog() !void {
    const red = dvui.Color{ .r = 255, .g = 0, .b = 0 };

    const S = struct {
        var pw1: [128]u8 = .{0} ** 128;
        var pw2: [128]u8 = .{0} ** 128;
        var pw_obf: bool = true;
    };

    const pw_err_msg = create.checkPw(S.pw1[0..main.slen(&S.pw1)], S.pw2[0..main.slen(&S.pw2)]);
    const pw_dont_match = if (pw_err_msg != null) red else null;

    var dialog_win = try dvui.floatingWindow(@src(), .{ .stay_above_parent = true, .modal = false, .open_flag = &gui.show_database_security_dialog }, .{
        .corner_radius = dvui.Rect.all(0),
        .min_size_content = .{ .w = 400.0, .h = 390.0 },
    });

    defer dialog_win.deinit();
    try dvui.windowHeader("Security", "", &gui.show_database_security_dialog);

    {
        var hbox = try dvui.box(@src(), .vertical, .{
            .expand = .horizontal,
            .margin = dvui.Rect{ .x = 7.0, .y = 0.0, .w = 7.0, .h = 0.0 },
            .padding = dvui.Rect.all(7),
        });
        defer hbox.deinit();

        try dvui.label(@src(), "Change Password", .{}, .{ .font_style = .title_4 });

        {
            var hbox2 = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
            defer hbox2.deinit();

            try dvui.label(@src(), "Enter Password:", .{}, .{ .gravity_y = 0.5 });

            var password1 = try dvui.textEntry(@src(), .{
                .text = &S.pw1,
                .password_char = if (S.pw_obf) "*" else null,
            }, .{
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(0),
                .color_border = pw_dont_match,
            });
            password1.deinit();

            if (try dvui.buttonIcon(
                @src(),
                "toggle",
                if (S.pw_obf) dvui.entypo.eye_with_line else dvui.entypo.eye,
                .{},
                .{
                    .gravity_y = 0.5,
                    .corner_radius = dvui.Rect.all(0),
                },
            )) {
                S.pw_obf = !S.pw_obf;
            }
        }

        {
            var hbox2 = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
            defer hbox2.deinit();

            try dvui.label(@src(), "Confirm Password:", .{}, .{ .gravity_y = 0.5 });

            var password2 = try dvui.textEntry(@src(), .{
                .text = &S.pw2,
                .password_char = if (S.pw_obf) "*" else null,
            }, .{
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(0),
                .color_border = pw_dont_match,
            });
            password2.deinit();
        }
    }

    {
        var hbox = try dvui.box(@src(), .horizontal, .{
            .expand = .horizontal,
            .margin = dvui.Rect{ .x = 7.0, .y = 0.0, .w = 7.0, .h = 0.0 },
            .padding = dvui.Rect.all(7),
        });
        defer hbox.deinit();

        if (try dvui.button(@src(), "Update password", .{}, .{
            .corner_radius = dvui.Rect.all(0),
            .gravity_x = 1.0,
            .gravity_y = 1.0,
        })) blk: {
            if (pw_dont_match != null) {
                break :blk;
            }

            // update password
            const pws = S.pw1[0..main.slen(&S.pw1)];
            var pw = try main.gpa.dupe(u8, pws);
            main.gpa.free(application_state.pw);
            application_state.pw = pw;

            // persist data
            try application_state.writeDb(main.gpa);

            @memset(S.pw1[0..], 0);
            @memset(S.pw2[0..], 0);

            gui.show_database_security_dialog = false;
            try dvui.toast(@src(), .{ .message = "Password successfully updated" });
        }
    }

    if (pw_dont_match != null) {
        try dvui.label(@src(), "{s}", .{pw_err_msg.?}, .{
            .color_text = pw_dont_match,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
        });
    }
}
