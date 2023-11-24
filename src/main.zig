const std = @import("std");
const tresor = @import("tresor");
const keylib = @import("keylib");
const cbor = @import("zbor");
const uhid = @import("uhid");
const dvui = @import("dvui");
const Backend = @import("SDLBackend");
const db = @import("db.zig");
const style = @import("style.zig");
const application_state = @import("state.zig");

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

const vsync = true;

var win: dvui.Window = undefined;

/// This example shows how to use the dvui for a normal application:
/// - dvui renders the whole application
/// - render frames only when needed
pub fn main() !void {

    // //////////////////////////////////////
    // GUI Init
    // //////////////////////////////////////

    // init SDL backend (creates OS window)
    var backend = try Backend.init(.{
        .width = 680,
        .height = 400,
        .vsync = vsync,
        .title = "PassKeeZ",
    });
    defer backend.deinit();

    // init dvui Window (maps onto a single OS window)
    win = try dvui.Window.init(@src(), 0, gpa, backend.backend());
    win.content_scale = backend.initial_scale;
    defer win.deinit();

    win.theme = &style.keypass_light;

    // //////////////////////////////////////
    // App Init
    // //////////////////////////////////////

    application_state.app_state = application_state.AppState{
        .states = std.ArrayList(application_state.AppState.State).init(gpa),
    };
    defer application_state.app_state.deinit();

    var config_file = db.Config.load(gpa) catch blk: {
        std.log.info("No configuration file found in `~/.keypass`", .{});
        try db.Config.create(gpa);
        var f = try db.Config.load(gpa);
        std.log.info("Configuration file created", .{});
        break :blk f;
    };

    try application_state.app_state.pushState(application_state.AppState.State{ .login = .{} });
    @memset(application_state.app_state.getState().login.path[0..], 0);
    @memcpy(
        application_state.app_state.getState().login.path[0..config_file.db_path.len],
        config_file.db_path,
    );

    config_file.deinit(gpa);
    // //////////////////////////////////////
    // Main
    // //////////////////////////////////////

    main_loop: while (true) {
        // beginWait coordinates with waitTime below to run frames only when needed
        var nstime = win.beginWait(backend.hasEvent());

        // marks the beginning of a frame for dvui, can call dvui functions after this
        try win.begin(nstime);

        // send all SDL events to dvui for processing
        const quit = try backend.addAllEvents(&win);
        if (quit) break :main_loop;

        try dvui_frame();

        // marks end of dvui frame, don't call dvui functions after this
        // - sends all dvui stuff to backend for rendering, must be called before renderPresent()
        const end_micros = try win.end(.{});

        // cursor management
        backend.setCursor(win.cursorRequested());

        // render frame to OS
        backend.renderPresent();

        // waitTime and beginWait combine to achieve variable framerates
        const wait_event_micros = win.waitTime(end_micros, null);
        backend.waitEventTimeout(wait_event_micros);
    }

    switch (application_state.app_state.getStateTag()) {
        .login => {},
        .main => {
            application_state.deinit(gpa);
        },
    }
}

var show_dialog: bool = false;
var show_create_dialog: bool = false;
fn dvui_frame() !void {
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
                    if (try dvui.menuItemLabel(@src(), "Lock Database", .{}, .{
                        .corner_radius = dvui.Rect.all(0),
                    }) != null) {
                        application_state.deinit(gpa);
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

    var scroll = try dvui.scrollArea(@src(), .{}, .{ .expand = .both, .color_style = .window });
    defer scroll.deinit();

    switch (application_state.app_state.getStateTag()) {
        .login => try login_frame(),
        .main => try main_frame(),
    }

    if (show_dialog) {
        try dialogInfo();
    }

    if (show_create_dialog) {
        try dialogDbCreate();
    }
}

fn checkPw(pw1: []const u8, pw2: []const u8) ?[]const u8 {
    if (!std.mem.eql(u8, pw1[0..], pw2[0..])) return "passwords don't match";
    if (pw1.len < 8) return "password must be at least 8 characters long";
    return null;
}

/// Dialog for creating a new database
pub fn dialogDbCreate() !void {
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

    const pw_err_msg = checkPw(S.pw1[0..slen(&S.pw1)], S.pw2[0..slen(&S.pw2)]);
    const pw_dont_match = if (pw_err_msg != null) red else null;

    var dialog_win = try dvui.floatingWindow(@src(), .{ .stay_above_parent = true, .modal = false, .open_flag = &show_create_dialog }, .{
        .corner_radius = dvui.Rect.all(0),
        .min_size_content = .{ .w = 400.0, .h = 390.0 },
    });

    defer dialog_win.deinit();
    try dvui.windowHeader("New Database", "", &show_create_dialog);

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
                .{
                    .gravity_y = 0.5,
                    .corner_radius = dvui.Rect.all(0),
                },
            )) {
                //var p = std.ChildProcess.init(&.{ "zenity", "--file-selection", "--directory" }, gpa);
                var r: ?std.ChildProcess.ExecResult = std.ChildProcess.exec(.{
                    .allocator = gpa,
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
                    gpa.free(_r.stdout);
                    gpa.free(_r.stderr);
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

        if (try dvui.button(@src(), "Create", .{
            .corner_radius = dvui.Rect.all(0),
            .gravity_x = 1.0,
            .gravity_y = 1.0,
        })) blk: {
            var valid = true;

            if (slen(S.db_name[0..]) == 0) {
                S.db_name_empty = red;
                valid = false;
            } else {
                S.db_name_empty = null;
            }

            if (pw_dont_match != null) {
                valid = false;
            }

            if (slen(&S.fname) == 0) {
                S.fname_empty = red;
                valid = false;
            } else {
                S.fname_empty = null;
            }

            if (slen(&S.fpath) == 0) {
                S.fpath_empty = red;
                valid = false;
            } else {
                S.fpath_empty = null;
            }

            if (!valid) {
                break :blk;
            }

            var absolute_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{
                S.fpath[0..slen(&S.fpath)],
                S.fname[0..slen(&S.fname)],
            });
            defer gpa.free(absolute_path);

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
                S.db_name[0..slen(&S.db_name)],
                gpa,
                std.crypto.random,
                std.time.milliTimestamp,
            );
            defer store.deinit();
            try store.seal(file.writer(), S.pw1[0..slen(&S.pw1)]);

            // Update the path of the database file
            var config_file = try db.Config.load(gpa);
            gpa.free(config_file.db_path);
            config_file.db_path = absolute_path;
            try config_file.save();

            show_create_dialog = false;
            // TODO: deinit all buffers
        }

        if (try dvui.button(@src(), "Cancel", .{
            .corner_radius = dvui.Rect.all(0),
            .gravity_x = 1.0,
            .gravity_y = 1.0,
        })) {}
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

pub fn dialogInfo() !void {
    var dialog_win = try dvui.floatingWindow(@src(), .{ .stay_above_parent = true, .modal = false, .open_flag = &show_dialog }, .{
        .corner_radius = dvui.Rect.all(0),
    });
    defer dialog_win.deinit();

    try dvui.windowHeader("About PassKeeZ", "", &show_dialog);
    try dvui.label(@src(), "About", .{}, .{ .font_style = .title_4 });

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "Website:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/r4gus/keypass", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/r4gus/keypass");
        }
    }

    try dvui.label(@src(), "PassKeeZ and keylib are distributed under the MIT license.", .{}, .{});
    try dvui.label(@src(), "Project Maintainers: David Sugar (r4gus)", .{}, .{});
    try dvui.label(@src(), "Special thanks to David Vanderson and\nthe whole Zig community.", .{}, .{});
    _ = dvui.spacer(@src(), .{}, .{ .expand = .vertical });
    try dvui.label(@src(), "Dependencies", .{}, .{ .font_style = .title_4 });

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "dvui:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/david-vanderson/dvui", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/david-vanderson/dvui");
        }
    }

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "keylib:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/r4gus/keylib", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/r4gus/keylib");
        }
    }

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "tresor:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/r4gus/tresor", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/r4gus/tresor");
        }
    }

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "zbor:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/r4gus/zbor", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/r4gus/zbor");
        }
    }
}

fn main_frame() !void {
    if (application_state.database.data.entries) |*entries| {
        if (entries.len > 1) {
            for (entries.*, 0..) |*entry, i| {
                if (entry.getField("Data", std.time.milliTimestamp())) |data| {
                    var buffer: [1024]u8 = .{0} ** 1024;
                    const slice = try std.fmt.hexToBytes(&buffer, data);

                    const cred = cbor.parse(
                        keylib.ctap.authenticator.Credential,
                        try cbor.DataItem.new(slice),
                        .{ .allocator = gpa },
                    ) catch {
                        continue;
                    };
                    defer cred.deinit(gpa);

                    var box = try dvui.box(@src(), .vertical, .{
                        .margin = dvui.Rect{ .x = 8.0, .y = 8.0, .w = 8.0 },
                        .padding = dvui.Rect.all(8),
                        .background = true,
                        .expand = .horizontal,
                        .id_extra = i,
                    });
                    defer box.deinit();

                    {
                        //var rp_box = try dvui.box(@src(), .vertical, .{});
                        //defer rp_box.deinit();

                        {
                            var hbox = try dvui.box(@src(), .horizontal, .{});
                            defer hbox.deinit();

                            try dvui.label(@src(), "Relying Party:", .{}, .{});
                            if (try dvui.labelClick(@src(), "{s}", .{cred.rp.id}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
                                if (cred.rp.id.len < 5 or !std.mem.eql(u8, "https", cred.rp.id[0..5])) {
                                    var rps = try gpa.alloc(u8, cred.rp.id.len + 8);
                                    defer gpa.free(rps);
                                    @memcpy(rps[0..8], "https://");
                                    @memcpy(rps[8..], cred.rp.id);
                                    try dvui.openURL(rps);
                                } else {
                                    try dvui.openURL(cred.rp.id);
                                }
                            }
                        }

                        //try dvui.label(@src(), "Relying Party: {s}", .{cred.rp.id}, .{ .gravity_y = 0.5 });
                        try dvui.label(@src(), "User: {s}", .{if (cred.user.displayName) |dn| blk: {
                            break :blk dn;
                        } else if (cred.user.name) |n| blk: {
                            break :blk n;
                        } else blk: {
                            break :blk "?";
                        }}, .{ .gravity_y = 0.5 });
                        try dvui.label(@src(), "Signatures Created: {d}", .{cred.sign_count}, .{ .gravity_y = 0.5 });
                        if (try dvui.button(@src(), "Delete", .{
                            .color_style = .err,
                            .corner_radius = dvui.Rect.all(0),
                            .gravity_x = 1.0,
                            .gravity_y = 1.0,
                        })) {}
                    }
                }
            }
        } else { // entries.len == 0
            try dvui.label(@src(), "No Passkeys available, go and create one!", .{}, .{ .font_style = .title_3, .gravity_x = 0.5, .gravity_y = 0.5 });
            if (try dvui.labelClick(@src(), "https://passkey.org/", .{}, .{ .font_style = .title_4, .gravity_x = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
                try dvui.openURL("https://passkey.org/");
            }
        }
    }
}

fn login_frame() !void {
    var s: ?application_state.AppState.State = null;

    const state = application_state.app_state.getState();

    var box = try dvui.box(@src(), .vertical, .{
        .margin = dvui.Rect{ .x = 50.0, .y = 50.0, .w = 50.0, .h = 75.0 },
        .padding = dvui.Rect.all(10),
        .background = true,
        .expand = .both,
        //.border = dvui.Rect.all(3),
    });
    defer box.deinit();

    {
        try dvui.label(@src(), "Enter Password:", .{}, .{ .font_style = .title_4 });

        var hbox = try dvui.box(@src(), .horizontal, .{
            //.margin = dvui.Rect.all(50),
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
        te.deinit();

        if (try dvui.buttonIcon(
            @src(),
            "toggle",
            if (state.login.pw_obf) dvui.entypo.eye_with_line else dvui.entypo.eye,
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
            .{
                .gravity_y = 0.5,
                .corner_radius = dvui.Rect.all(0),
            },
        )) {
            //var p = std.ChildProcess.init(&.{ "zenity", "--file-selection", "--directory" }, gpa);
            var r: ?std.ChildProcess.ExecResult = std.ChildProcess.exec(.{
                .allocator = gpa,
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
                    var config_file = try db.Config.load(gpa);
                    gpa.free(config_file.db_path);
                    config_file.db_path = state.login.path[0..l];
                    try config_file.save();
                }

                gpa.free(_r.stdout);
                gpa.free(_r.stderr);
            }
        }
    }
    {
        if (try dvui.button(@src(), "Unlock", .{
            .corner_radius = dvui.Rect.all(0),
            .gravity_x = 1.0,
            .gravity_y = 1.0,
        })) blk: {
            application_state.dvui_dbOpen(
                state.login.path[0..slen(&state.login.path)],
                state.login.pw[0..slen(&state.login.pw)],
                gpa,
            ) catch {
                break :blk;
            };

            s = .{
                .main = .{
                    .t = try std.Thread.spawn(.{}, auth_fn, .{}),
                },
            };
            application_state.pw = try gpa.dupe(u8, state.login.pw[0..slen(&state.login.pw)]);
            application_state.f = try gpa.dupe(u8, state.login.path[0..strlen(&state.login.path)]);
            @memset(state.login.pw[0..], 0);
        }
    }

    if (s) |_s| {
        try application_state.app_state.pushState(_s);
    }
}

inline fn slen(s: []const u8) usize {
    return std.mem.indexOfScalar(u8, s, 0) orelse s.len;
}

fn strlen(s: [*c]const u8) usize {
    var i: usize = 0;
    while (s[i] != 0) : (i += 1) {}
    return i;
}

// /////////////////////////////////////////
// Auth
// /////////////////////////////////////////

const UpResult = keylib.ctap.authenticator.callbacks.UpResult;
const UvResult = keylib.ctap.authenticator.callbacks.UvResult;
const Error = keylib.ctap.authenticator.callbacks.Error;

pub fn my_uv(
    /// Information about the context (e.g., make credential)
    info: [*c]const u8,
    /// Information about the user (e.g., `David Sugar (david@example.com)`)
    user: [*c]const u8,
    /// Information about the relying party (e.g., `Github (github.com)`)
    rp: [*c]const u8,
) callconv(.C) UvResult {
    _ = info;
    _ = user;
    _ = rp;
    // The authenticator backend is only started if a correct password has been provided
    // so we return Accepted. As this state may last for multiple minutes it's important
    // that we ask for user presence, i.e. we DONT return AcceptedWithUp!
    //
    // TODO: "logout after being inactive for m minutes"
    return UvResult.Accepted;
}

pub fn my_up(
    /// Information about the context (e.g., make credential)
    info: [*c]const u8,
    /// Information about the user (e.g., `David Sugar (david@example.com)`)
    user: [*c]const u8,
    /// Information about the relying party (e.g., `Github (github.com)`)
    rp: [*c]const u8,
) callconv(.C) UpResult {
    if (info) |i| {
        std.log.info("{s}", .{i});
    }

    const dialogsFollowup = struct {
        var confirm: ?bool = null;
        fn callafter(id: u32, response: dvui.enums.DialogResponse) dvui.Error!void {
            _ = id;
            confirm = (response == dvui.enums.DialogResponse.ok);
        }
    };

    const begin = std.time.milliTimestamp();

    const title = std.fmt.allocPrint(gpa, "User Presence Check{s}{s}", .{
        if (info != null) ": " else "",
        if (info != null) info[0..strlen(info)] else "",
    }) catch blk: {
        break :blk "oops";
    };

    var message = std.fmt.allocPrint(gpa, "Please confirm your presence for {s} {s}{s}{s} by clicking ok", .{
        if (rp != null) rp[0..strlen(rp)] else "???",
        if (user != null) "(" else "",
        if (user != null) user[0..strlen(user)] else "",
        if (user != null) "(" else "",
    }) catch blk: {
        break :blk "oops";
    };

    dvui.dialog(@src(), .{
        .window = &win,
        .modal = false,
        .title = title,
        .message = message,
        .callafterFn = dialogsFollowup.callafter,
    }) catch return .Denied;

    while (std.time.milliTimestamp() - begin < 60_000) {
        // If the authenticator thread gets a stop signal, return timeout
        if (application_state.app_state.getState().main.stop) {
            return .Timeout;
        }

        if (dialogsFollowup.confirm != null) {
            defer dialogsFollowup.confirm = null;
            if (dialogsFollowup.confirm.?) {
                return .Accepted;
            } else {
                return .Denied;
            }
        }
        std.time.sleep(10000000);
    }

    return UpResult.Timeout;
}

pub fn my_select(
    rpId: [*c]const u8,
    users: [*c][*c]const u8,
) callconv(.C) i32 {
    _ = rpId;
    _ = users;
    return 0;
}

pub fn my_read(
    id: [*c]const u8,
    rp: [*c]const u8,
    out: *[*c][*c]u8,
) callconv(.C) Error {
    if (id != null) {
        if (application_state.database.getEntry(id[0..strlen(id)])) |*e| {
            if (e.*.getField("Data", std.time.microTimestamp())) |data| {
                var d = gpa.alloc(u8, data.len + 1) catch {
                    std.log.err("out of memory", .{});
                    return Error.OutOfMemory;
                };
                @memcpy(d[0..data.len], data);
                d[data.len] = 0;
                //var d = gpa.dupeZ(u8, data) catch {
                //    std.log.err("out of memory", .{});
                //    return Error.OutOfMemory;
                //};

                var x = gpa.alloc([*c]u8, 2) catch {
                    std.log.err("out of memory", .{});
                    return Error.OutOfMemory;
                };

                x[0] = d.ptr;
                x[1] = null;
                out.* = x.ptr;

                return Error.SUCCESS;
            } else {
                std.log.err("Data field not present", .{});
                return Error.Other;
            }
        } else {
            std.log.warn("no entry with id {s} found", .{id[0..strlen(id)]});
            return Error.DoesNotExist;
        }
    } else if (rp != null) {
        var arr = std.ArrayList([*c]u8).init(gpa);
        if (application_state.database.getEntries(
            &.{.{ .key = "Url", .value = rp[0..strlen(rp)] }},
            gpa,
        )) |entries| {
            for (entries) |*e| {
                if (e.*.getField("Data", std.time.microTimestamp())) |data| {
                    var d = gpa.dupeZ(u8, data) catch {
                        std.log.err("out of memory", .{});
                        return Error.OutOfMemory;
                    };
                    arr.append(d) catch {
                        std.log.err("out of memory", .{});
                        return Error.OutOfMemory;
                    };
                } else {
                    std.log.err("Data field not present", .{});
                    continue;
                }
            }
        }

        if (arr.items.len > 0) {
            var x = arr.toOwnedSliceSentinel(null) catch {
                std.log.err("out of memory", .{});
                arr.deinit();
                return Error.OutOfMemory;
            };
            out.* = x.ptr;
            return Error.SUCCESS;
        } else {
            arr.deinit();
            return Error.DoesNotExist;
        }
    }

    return Error.DoesNotExist;
}

pub fn my_write(
    id: [*c]const u8,
    rp: [*c]const u8,
    data: [*c]const u8,
) callconv(.C) Error {
    if (application_state.database.getEntry(id[0..strlen(id)])) |*e| {
        e.*.updateField("Data", data[0..strlen(data)], std.time.milliTimestamp()) catch {
            std.log.err("unable to update field", .{});
            return Error.Other;
        };
    } else {
        var e = application_state.database.createEntry(id[0..strlen(id)]) catch {
            std.log.err("unable to create new entry", .{});
            return Error.Other;
        };

        e.addField(
            "Url",
            rp[0..strlen(rp)],
            std.time.milliTimestamp(),
        ) catch {
            std.log.err("unable to add Url field", .{});
            e.deinit();
            return Error.Other;
        };

        e.addField(
            "Data",
            data[0..strlen(data)],
            std.time.milliTimestamp(),
        ) catch {
            std.log.err("unable to add Data field", .{});
            e.deinit();
            return Error.Other;
        };

        application_state.database.addEntry(e) catch {
            std.log.err("unable to add entry to database", .{});
            e.deinit();
            return Error.Other;
        };
    }

    var f2 = std.fs.createFileAbsolute("/tmp/db.trs", .{ .truncate = true }) catch {
        std.log.err("unable to open temporary file in /tmp", .{});
        return Error.Other;
    };
    defer f2.close();

    application_state.database.seal(f2.writer(), application_state.pw) catch {
        std.log.err("unable to persist database", .{});
        return Error.Other;
    };

    if (application_state.f[0] == '~' and application_state.f[1] == '/') {
        if (std.os.getenv("HOME")) |home| {
            var path = std.fmt.allocPrint(gpa, "{s}/{s}", .{ home, application_state.f[2..] }) catch {
                std.log.err("out of memory", .{});
                return Error.Other;
            };
            defer gpa.free(path);
            std.log.err("{s}", .{path});

            std.fs.copyFileAbsolute("/tmp/db.trs", path, .{}) catch {
                std.log.err("unable to overwrite file `{s}`", .{application_state.f});
                return Error.Other;
            };
        } else {
            std.log.err("no HOME path", .{});
            return Error.Other;
        }
    } else if (application_state.f[0] == '/') {
        std.fs.copyFileAbsolute("/tmp/db.trs", application_state.f, .{}) catch {
            std.log.err("unable to overwrite file `{s}`", .{application_state.f});
            return Error.Other;
        };
    } else {
        std.log.err("support for file prefix not implemented yet!!!", .{});
        return Error.Other;
    }

    return Error.SUCCESS;
}

pub fn my_delete(
    id: [*c]const u8,
) callconv(.C) Error {
    _ = id;
    return Error.Other;
}

const callbacks = keylib.ctap.authenticator.callbacks.Callbacks{
    .up = my_up,
    .uv = my_uv,
    .select = my_select,
    .read = my_read,
    .write = my_write,
    .delete = my_delete,
};

fn auth_fn() !void {
    var auth = keylib.ctap.authenticator.Auth.default(callbacks, gpa);
    auth.constSignCount = true;
    try auth.init();

    var ctaphid = keylib.ctap.transports.ctaphid.authenticator.CtapHid.init(gpa);
    defer ctaphid.deinit();

    var u = try uhid.Uhid.open();
    defer u.close();

    while (true) {
        var buffer: [64]u8 = .{0} ** 64;
        if (u.read(&buffer)) |packet| {
            var response = ctaphid.handle(packet, &auth);
            if (response) |*res| blk: {
                defer res.deinit();

                while (res.next()) |p| {
                    u.write(p) catch {
                        break :blk;
                    };
                }
            }
        }
        std.time.sleep(10000000);

        // We send all data back before we end the thread
        if (application_state.app_state.getState().main.stop) {
            return;
        }
    }
}
