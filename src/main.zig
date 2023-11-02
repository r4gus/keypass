const std = @import("std");
const tresor = @import("tresor");
const keylib = @import("keylib");
const cbor = @import("zbor");
const uhid = @import("uhid");
const dvui = @import("dvui");
const Backend = @import("SDLBackend");
const db = @import("db.zig");
const style = @import("style.zig");

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

const vsync = true;

const DB = struct {
    var database: tresor.Tresor = undefined;
    var lock: std.Thread.Mutex = .{};
    var pw: []const u8 = undefined;
    var f: []const u8 = undefined;
};

const AppState = struct {
    pub const StateTag = enum {
        login,
        main,
    };

    pub const State = union(StateTag) {
        login: struct {
            pw_obf: bool = true,
            pw: [128]u8 = .{0} ** 128,
            path: [256]u8 = ("~/.keypass/db.trs" ++ .{0} ** 239).*,
        },
        main: struct {
            t: std.Thread,
        },
    };

    lock: std.Thread.Mutex = .{},
    states: std.ArrayList(State),

    pub fn lockState(self: *AppState) ?*State {
        if (self.states.items.len > 0) {
            self.lock.lock();
            return &self.states.items[self.states.items.len - 1];
        }
        return null;
    }

    pub fn unlockState(self: *AppState) void {
        self.lock.unlock();
    }

    pub fn getState(self: *AppState) ?StateTag {
        self.lock.lock();
        defer self.lock.unlock();
        if (self.states.items.len > 0) {
            return switch (self.states.items[self.states.items.len - 1]) {
                .login => StateTag.login,
                .main => StateTag.main,
            };
        }
        return null;
    }

    pub fn pushState(self: *AppState, state: State) !void {
        self.lock.lock();
        defer self.lock.unlock();
        try self.states.append(state);
    }

    pub fn popState(self: *AppState) void {
        self.lock.lock();
        defer self.lock.unlock();
        _ = self.states.pop();
    }

    pub fn deinit(self: *AppState) void {
        for (self.states.items) |*item| {
            switch (item.*) {
                .login => {},
                .main => |*m| {
                    _ = m;
                },
            }
        }
        self.states.deinit();
    }
};

var app_state = AppState{
    .states = std.ArrayList(AppState.State).init(gpa),
};

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
        .title = "KeyPass",
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

    var config_file = db.Config.load(gpa) catch blk: {
        std.log.info("No configuration file found in `~/.keypass`", .{});
        try db.Config.create(gpa);
        var f = try db.Config.load(gpa);
        std.log.info("Configuration file created", .{});
        break :blk f;
    };
    defer config_file.deinit(gpa);

    defer app_state.deinit();
    try app_state.pushState(AppState.State{ .login = .{} });
    @memset(app_state.states.items[app_state.states.items.len - 1].login.path[0..], 0);
    @memcpy(
        app_state.states.items[app_state.states.items.len - 1].login.path[0..config_file.db_path.len],
        config_file.db_path,
    );

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
                //var p = std.ChildProcess.init(&.{ "zenity", "--file-selection", "--directory" }, gpa);
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

    if (app_state.getState()) |state| {
        switch (state) {
            .login => try login_frame(),
            .main => try main_frame(),
        }
    }

    if (show_dialog) {
        try dialogInfo();
    }

    if (show_create_dialog) {
        try dialogDbCreate();
    }
}

pub fn dialogDbCreate() !void {
    var dialog_win = try dvui.floatingWindow(@src(), .{ .stay_above_parent = true, .modal = false, .open_flag = &show_create_dialog }, .{});
    defer dialog_win.deinit();
    try dvui.windowHeader("New Database", "", &show_create_dialog);

    try dvui.label(@src(), "comming soon...", .{}, .{});
}

pub fn dialogInfo() !void {
    var dialog_win = try dvui.floatingWindow(@src(), .{ .stay_above_parent = true, .modal = false, .open_flag = &show_dialog }, .{});
    defer dialog_win.deinit();

    try dvui.windowHeader("About KeyPass", "", &show_dialog);
    try dvui.label(@src(), "About", .{}, .{ .font_style = .title_4 });

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "Website:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/r4gus/keypass", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/r4gus/keypass");
        }
    }

    try dvui.label(@src(), "KeyPass and keylib are distributed under the MIT license.", .{}, .{});
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
    if (DB.database.data.entries) |*entries| {
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
    }
}

fn login_frame() !void {
    var s: ?AppState.State = null;

    if (app_state.lockState()) |state| {
        defer app_state.unlockState();

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
        }
        {
            if (try dvui.button(@src(), "Unlock", .{
                .corner_radius = dvui.Rect.all(0),
                .gravity_x = 1.0,
                .gravity_y = 1.0,
            })) blk: {
                var database = db.open(
                    state.login.path[0..strlen(&state.login.path)],
                    state.login.pw[0..strlen(&state.login.pw)],
                    gpa,
                ) catch |e| {
                    if (e == error.NotFound) {
                        try dvui.dialog(@src(), .{
                            .modal = false,
                            .title = "File not found",
                            .message = "The given file does not exist",
                        });
                    } else {
                        try dvui.dialog(@src(), .{
                            .modal = false,
                            .title = "Unlock error",
                            .message = "Unable to unlock the database. Did you enter the correct password?",
                        });
                    }
                    break :blk;
                };

                s = .{
                    .main = .{
                        .t = try std.Thread.spawn(.{}, auth_fn, .{}),
                    },
                };
                DB.pw = try gpa.dupe(u8, state.login.pw[0..strlen(&state.login.pw)]);
                DB.f = try gpa.dupe(u8, state.login.path[0..strlen(&state.login.path)]);
                DB.database = database;
            }
        }
    }

    if (s) |state| {
        try app_state.pushState(state);
    }
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
        //win.refresh();
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
    DB.lock.lock();
    defer DB.lock.unlock();

    if (id != null) {
        if (DB.database.getEntry(id[0..strlen(id)])) |*e| {
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
        if (DB.database.getEntries(
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
    DB.lock.lock();
    defer DB.lock.unlock();

    if (DB.database.getEntry(id[0..strlen(id)])) |*e| {
        e.*.updateField("Data", data[0..strlen(data)], std.time.milliTimestamp()) catch {
            std.log.err("unable to update field", .{});
            return Error.Other;
        };
    } else {
        var e = DB.database.createEntry(id[0..strlen(id)]) catch {
            std.log.err("unable to create new entry", .{});
            return Error.Other;
        };

        e.addField(
            .{ .key = "Url", .value = rp[0..strlen(rp)] },
            std.time.milliTimestamp(),
        ) catch {
            std.log.err("unable to add Url field", .{});
            e.deinit();
            return Error.Other;
        };

        e.addField(
            .{ .key = "Data", .value = data[0..strlen(data)] },
            std.time.milliTimestamp(),
        ) catch {
            std.log.err("unable to add Data field", .{});
            e.deinit();
            return Error.Other;
        };

        DB.database.addEntry(e) catch {
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

    DB.database.seal(f2.writer(), DB.pw) catch {
        std.log.err("unable to persist database", .{});
        return Error.Other;
    };

    if (DB.f[0] == '~' and DB.f[1] == '/') {
        if (std.os.getenv("HOME")) |home| {
            var path = std.fmt.allocPrint(gpa, "{s}/{s}", .{ home, DB.f[2..] }) catch {
                std.log.err("out of memory", .{});
                return Error.Other;
            };
            defer gpa.free(path);
            std.log.err("{s}", .{path});

            std.fs.copyFileAbsolute("/tmp/db.trs", path, .{}) catch {
                std.log.err("unable to overwrite file", .{});
                return Error.Other;
            };
        } else {
            std.log.err("no HOME path", .{});
            return Error.Other;
        }
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
    }
}
