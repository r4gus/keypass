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
