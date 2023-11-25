const std = @import("std");
const dvui = @import("dvui");
const main = @import("../main.zig");
const tresor = @import("tresor");
const db = @import("../db.zig");
const gui = @import("../gui.zig");

/// Dialog for creating a new database
pub fn create_db_dialog() !void {
    const red = dvui.Color{ .r = 255, .g = 0, .b = 0 };

    const S = struct {
        var db_name: [128]u8 = .{0} ** 128;
        var db_name_empty: ?dvui.Color = null;
        var pw1: [128]u8 = .{0} ** 128;
        var pw2: [128]u8 = .{0} ** 128;
        var fname: [256]u8 = .{0} ** 256;
        var fname_empty: ?dvui.Color = null;
        var fpath: [256]u8 = .{0} ** 256;
        var fpath_empty: ?dvui.Color = null;
        var fpath_err: ?[]const u8 = null;
        var pw_obf: bool = true;
    };

    const pw_err_msg = checkPw(S.pw1[0..main.slen(&S.pw1)], S.pw2[0..main.slen(&S.pw2)]);
    const pw_dont_match = if (pw_err_msg != null) red else null;

    var dialog_win = try dvui.floatingWindow(@src(), .{ .stay_above_parent = true, .modal = false, .open_flag = &gui.show_create_dialog }, .{
        .corner_radius = dvui.Rect.all(0),
        .min_size_content = .{ .w = 400.0, .h = 390.0 },
    });

    defer dialog_win.deinit();
    try dvui.windowHeader("New Database", "", &gui.show_create_dialog);

    {
        var hbox = try dvui.box(@src(), .vertical, .{
            .expand = .horizontal,
            .margin = dvui.Rect{ .x = 7.0, .y = 7.0, .w = 7.0, .h = 7.0 },
            .padding = dvui.Rect.all(7),
        });
        defer hbox.deinit();

        {
            try dvui.label(@src(), "General Information", .{}, .{ .font_style = .title_4 });

            var hbox2 = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
            defer hbox2.deinit();

            try dvui.label(@src(), "Database Name:", .{}, .{ .gravity_y = 0.5 });

            var name = try dvui.textEntry(@src(), .{
                .text = &S.db_name,
                .password_char = null,
            }, .{
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(0),
                .color_border = S.db_name_empty,
            });
            name.deinit();
        }
    }

    // TODO: encyption settings?

    {
        var hbox = try dvui.box(@src(), .vertical, .{
            .expand = .horizontal,
            .margin = dvui.Rect{ .x = 7.0, .y = 0.0, .w = 7.0, .h = 0.0 },
            .padding = dvui.Rect.all(7),
        });
        defer hbox.deinit();

        try dvui.label(@src(), "Credentials", .{}, .{ .font_style = .title_4 });

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
        var hbox = try dvui.box(@src(), .vertical, .{
            .expand = .horizontal,
            .margin = dvui.Rect{ .x = 7.0, .y = 0.0, .w = 7.0, .h = 0.0 },
            .padding = dvui.Rect.all(7),
        });
        defer hbox.deinit();

        try dvui.label(@src(), "File System", .{}, .{ .font_style = .title_4 });

        {
            var hbox2 = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
            defer hbox2.deinit();

            try dvui.label(@src(), "File Name:", .{}, .{ .gravity_y = 0.5 });

            var fname = try dvui.textEntry(@src(), .{
                .text = &S.fname,
                .password_char = null,
            }, .{
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(0),
                .color_border = S.fname_empty,
            });
            fname.deinit();
        }

        {
            var hbox2 = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
            defer hbox2.deinit();

            try dvui.label(@src(), "File Path:", .{}, .{ .gravity_y = 0.5 });

            var fpath = try dvui.textEntry(@src(), .{
                .text = &S.fpath,
                .password_char = null,
            }, .{
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(0),
                .color_border = S.fpath_empty,
            });
            fpath.deinit();

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
                    .argv = &.{ "zenity", "--file-selection", "--directory" },
                }) catch blk: {
                    break :blk null;
                };

                if (r) |_r| {
                    if (_r.stdout.len > 0) {
                        var l = if (_r.stdout.len > S.fpath[0..].len) S.fpath[0..].len else _r.stdout.len;
                        // Remove whitespace
                        while (l > 0 and std.ascii.isWhitespace(_r.stdout[l - 1])) : (l -= 1) {}
                        @memcpy(S.fpath[0..l], _r.stdout[0..l]);
                    }

                    std.log.err("{s}\n{s}", .{ _r.stdout, _r.stderr });
                    main.gpa.free(_r.stdout);
                    main.gpa.free(_r.stderr);
                }
            }
        }
    }

    {
        var hbox = try dvui.box(@src(), .horizontal, .{
            .expand = .horizontal,
            .margin = dvui.Rect{ .x = 7.0, .y = 0.0, .w = 7.0, .h = 0.0 },
            .padding = dvui.Rect.all(7),
        });
        defer hbox.deinit();

        if (try dvui.button(@src(), "Create", .{}, .{
            .corner_radius = dvui.Rect.all(0),
            .gravity_x = 1.0,
            .gravity_y = 1.0,
        })) blk: {
            var valid = true;

            if (main.slen(S.db_name[0..]) == 0) {
                S.db_name_empty = red;
                valid = false;
            } else {
                S.db_name_empty = null;
            }

            if (pw_dont_match != null) {
                valid = false;
            }

            if (main.slen(&S.fname) == 0) {
                S.fname_empty = red;
                valid = false;
            } else {
                S.fname_empty = null;
            }

            if (main.slen(&S.fpath) == 0) {
                S.fpath_empty = red;
                valid = false;
            } else {
                S.fpath_empty = null;
            }

            if (!valid) {
                break :blk;
            }

            var absolute_path = try std.fmt.allocPrint(main.gpa, "{s}/{s}", .{
                S.fpath[0..main.slen(&S.fpath)],
                S.fname[0..main.slen(&S.fname)],
            });
            defer main.gpa.free(absolute_path);

            var file = std.fs.createFileAbsolute(absolute_path, .{ .exclusive = true }) catch |e| {
                if (e == error.PathAlreadyExists) {
                    S.fpath_err = "the file does already exist";
                    break :blk;
                } else if (e == error.AccessDenied) {
                    S.fpath_err = "file access denied";
                    break :blk;
                } else {
                    S.fpath_err = "unexpected error while opening file";
                    break :blk;
                }
            };
            defer file.close();
            S.fpath_err = null;

            var store = try tresor.Tresor.new(
                1,
                0,
                .ChaCha20,
                .None,
                .Argon2id,
                "PassKey",
                S.db_name[0..main.slen(&S.db_name)],
                main.gpa,
                std.crypto.random,
                std.time.milliTimestamp,
            );
            defer store.deinit();
            try store.seal(file.writer(), S.pw1[0..main.slen(&S.pw1)]);

            // Update the path of the database file
            var config_file = try db.Config.load(main.gpa);
            main.gpa.free(config_file.db_path);
            config_file.db_path = absolute_path;
            try config_file.save();

            gui.show_create_dialog = false;
            // TODO: deinit all buffers
        }

        if (try dvui.button(@src(), "Cancel", .{}, .{
            .corner_radius = dvui.Rect.all(0),
            .gravity_x = 1.0,
            .gravity_y = 1.0,
        })) {
            gui.show_create_dialog = false;
        }
    }

    if (pw_dont_match != null) {
        try dvui.label(@src(), "{s}", .{pw_err_msg.?}, .{
            .color_text = pw_dont_match,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
        });
    }

    if (S.db_name_empty != null) {
        try dvui.label(@src(), "database name must not be empty", .{}, .{
            .color_text = S.db_name_empty,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
        });
    }

    if (S.fpath_err) |e| {
        try dvui.label(@src(), "{s}", .{e}, .{
            .color_text = red,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
        });
    }
}

fn checkPw(pw1: []const u8, pw2: []const u8) ?[]const u8 {
    if (!std.mem.eql(u8, pw1[0..], pw2[0..])) return "passwords don't match";
    if (pw1.len < 8) return "password must be at least 8 characters long";
    return null;
}
