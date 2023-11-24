const std = @import("std");
const tresor = @import("tresor");
const db = @import("db.zig");
const dvui = @import("dvui");

/// The password used to en-/decrypt the credential database.
///
/// This variable is set during the "login phase".
///
/// This should be overwritten, as soon as its not required anymore.
pub var pw: []u8 = undefined;
/// Path to the credential database.
///
/// This variable is set during the "login phase".
pub var f: []u8 = undefined;

/// The open database
///
/// This variable is accessed by the main and the authenticator
/// thread if the application is in `main` state.
///
/// TODO: currently the main thread uses the database only for reading
///       but we probably need a lock in the future.
pub var database: tresor.Tresor = undefined;

/// The current state the application is in.
pub var app_state: AppState = undefined;

/// Open the credential database using the provided `path` and `password`.
///
/// The caller is responsible to `deinit` the credential database.
pub fn dvui_dbOpen(
    path: []const u8,
    password: []const u8,
    allocator: std.mem.Allocator,
) !void {
    database = db.open(
        path,
        password,
        allocator,
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
        return e;
    };
}

pub fn deinit() void {
    // TODO
}

pub const AppState = struct {
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
            stop: bool = false,
        },
    };

    states: std.ArrayList(State),

    pub fn getState(self: *AppState) *State {
        return &self.states.items[self.states.items.len - 1];
    }

    pub fn getStateTag(self: *AppState) StateTag {
        return switch (self.states.items[self.states.items.len - 1]) {
            .login => StateTag.login,
            .main => StateTag.main,
        };
    }

    pub fn pushState(self: *AppState, state: State) !void {
        try self.states.append(state);
    }

    pub fn popState(self: *AppState) void {
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
