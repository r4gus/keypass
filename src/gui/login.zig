const std = @import("std");
const application_state = @import("../state.zig");
const dvui = @import("dvui");
const db = @import("../db.zig");
const main = @import("../main.zig");

pub fn login_frame() !void {
    const state = application_state.app_state.getState();
    var enter_pressed = false;

    var box = try dvui.box(@src(), .vertical, .{
        .margin = dvui.Rect{ .x = 50.0, .y = 50.0, .w = 50.0, .h = 75.0 },
        .padding = dvui.Rect.all(10),
        .background = true,
        .expand = .both,
    });
    defer box.deinit();

    {
        try dvui.label(@src(), "Enter Password:", .{}, .{ .font_style = .title_4 });

        var hbox = try dvui.box(@src(), .horizontal, .{
            .expand = .horizontal,
        });
        defer hbox.deinit();

        var te = try dvui.textEntry(@src(), .{
            .text = &state.login.pw,
            .password_char = if (state.login.pw_obf) "*" else null,
        }, .{
            .expand = .horizontal,
            .corner_radius = dvui.Rect.all(0),
        });

        for (dvui.events()) |*e| {
            if (!te.matchEvent(e)) {
                continue;
            }

            if (e.evt == .key and e.evt.key.code == .enter and e.evt.key.action == .down) {
                e.handled = true;
                enter_pressed = true;
            }

            if (!e.handled) {
                te.processEvent(e, false);
            }
        }
        te.deinit();

        if (try dvui.buttonIcon(
            @src(),
            "toggle",
            if (state.login.pw_obf) dvui.entypo.eye_with_line else dvui.entypo.eye,
            .{},
            .{
                .gravity_y = 0.5,
                .corner_radius = dvui.Rect.all(0),
            },
        )) {
            state.login.pw_obf = !state.login.pw_obf;
        }
    }
    {
        try dvui.label(@src(), "Database File:", .{}, .{ .font_style = .title_4 });

        var hbox = try dvui.box(@src(), .horizontal, .{
            .expand = .horizontal,
        });
        defer hbox.deinit();

        var te = try dvui.textEntry(@src(), .{
            .text = &state.login.path,
            .password_char = null,
        }, .{
            .expand = .horizontal,
            .corner_radius = dvui.Rect.all(0),
        });
        te.deinit();

        if (try dvui.buttonIcon(
            @src(),
            "fileDialog",
            dvui.entypo.browser,
            .{},
            .{
                .gravity_y = 0.5,
                .corner_radius = dvui.Rect.all(0),
            },
        )) {
            var r: ?std.ChildProcess.ExecResult = std.ChildProcess.exec(.{
                .allocator = main.gpa,
                .argv = &.{ "zenity", "--file-selection" },
            }) catch blk: {
                break :blk null;
            };

            if (r) |_r| {
                if (_r.stdout.len > 0) {
                    var l = if (_r.stdout.len > state.login.path[0..].len) state.login.path[0..].len else _r.stdout.len;
                    // Remove whitespace
                    while (l > 0 and std.ascii.isWhitespace(_r.stdout[l - 1])) : (l -= 1) {}
                    @memset(state.login.path[0..], 0);
                    @memcpy(state.login.path[0..l], _r.stdout[0..l]);

                    // Update the path of the database file
                    var config_file = try db.Config.load(main.gpa);
                    main.gpa.free(config_file.db_path);
                    config_file.db_path = state.login.path[0..l];
                    try config_file.save();
                }

                main.gpa.free(_r.stdout);
                main.gpa.free(_r.stderr);
            }
        }
    }
    {
        if (try dvui.button(@src(), "Unlock", .{}, .{
            .corner_radius = dvui.Rect.all(0),
            .gravity_x = 1.0,
            .gravity_y = 1.0,
        }) or enter_pressed) blk: {
            application_state.dvui_dbOpen(
                state.login.path[0..main.slen(&state.login.path)],
                state.login.pw[0..main.slen(&state.login.pw)],
                main.gpa,
            ) catch {
                break :blk;
            };

            var s = application_state.AppState.State{
                .main = .{
                    .t = try std.Thread.spawn(.{}, main.auth_fn, .{}),
                },
            };
            application_state.pw = try main.gpa.dupe(u8, state.login.pw[0..main.slen(&state.login.pw)]);
            application_state.f = try main.gpa.dupe(u8, state.login.path[0..main.strlen(&state.login.path)]);
            try application_state.app_state.pushState(s);
            @memset(state.login.pw[0..], 0);
        }
    }
}
