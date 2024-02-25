const std = @import("std");
const tresor = @import("tresor");
const db = @import("db.zig");
const dvui = @import("dvui");
const keylib = @import("keylib");
const UpResult = keylib.ctap.authenticator.callbacks.UpResult;
const UvResult = keylib.ctap.authenticator.callbacks.UvResult;

/// The password used to en-/decrypt the credential database.
///
/// This variable is set during the "login phase".
///
/// This should be overwritten, as soon as its not required anymore.
pub var pw: []u8 = undefined;

pub var conf: db.Config = undefined;

/// The open database
///
/// This variable is accessed by the main and the authenticator
/// thread if the application is in `main` state.
///
/// TODO: currently the main thread uses the database only for reading
///       but we probably need a lock in the future.
pub var database: tresor.Tresor = undefined;

pub var uv_result = UvResult.Denied;
pub var up_result: ?UpResult = null;

var ts: ?i64 = null;
const tout1: i64 = 10; // seconds
const tout2: i64 = 60; // seconds

pub fn init(a: std.mem.Allocator) !void {
    conf = db.Config.load(a) catch blk: {
        std.log.info("No configuration file found in `~/.keypass`", .{});
        try db.Config.create(a);
        var conf_ = try db.Config.load(a);
        std.log.info("Configuration file created", .{});
        break :blk conf_;
    };
}

pub fn update(a: std.mem.Allocator) void {
    if (ts) |ts_| {
        const now = std.time.timestamp();
        if (now - ts_ > tout2) {
            deinit(a);
        } else if (now - ts_ > tout1) {
            // Requre UP after 10 seconds
            uv_result = UvResult.Accepted;
            up_result = null;
        }
    }
}

pub fn authenticate(a: std.mem.Allocator) !void {
    if (ts != null) return; // nothing to do

    var i: usize = 3;

    const f = db.openFile(conf.db_path) catch blk: {
        break :blk createDialog(a) catch |e| {
            std.log.err("db creation failed ({any})", .{e});
            return e;
        };
    };
    f.close();

    outer: while (i > 0) : (i -= 1) {
        var password: std.ChildProcess.ExecResult = try std.ChildProcess.exec(.{
            .allocator = a,
            .argv = &.{
                "zenity",
                "--password",
                "--title=Unlock credential database",
                "--ok-label=unlock",
                "--timeout=60",
            },
        });
        defer {
            a.free(password.stdout);
            a.free(password.stderr);
        }
        std.log.info("{any}", .{password});

        switch (password.term.Exited) {
            0 => {
                database = db.open(
                    conf.db_path,
                    password.stdout[0 .. password.stdout.len - 1],
                    a,
                ) catch |e| {
                    std.log.err("unable to decrypt database {s} ({any})", .{ conf.db_path, e });
                    const r = try std.ChildProcess.exec(.{
                        .allocator = a,
                        .argv = &.{ "zenity", "--warning", "--text=Wrong password" },
                    });
                    defer {
                        a.free(r.stdout);
                        a.free(r.stderr);
                    }
                    continue :outer;
                };

                pw = try a.dupe(u8, password.stdout[0 .. password.stdout.len - 1]);
                ts = std.time.timestamp();
                uv_result = UvResult.AcceptedWithUp;
                up_result = UpResult.Accepted;
                return;
            },
            else => {
                return error.RejectedByUser;
            },
        }
    } else {
        const r = try std.ChildProcess.exec(.{
            .allocator = a,
            .argv = &.{ "zenity", "--error", "--text=Authentication failed" },
        });
        defer {
            a.free(r.stdout);
            a.free(r.stderr);
        }
        return error.Failed;
    }
}

pub fn writeDb(gpa: std.mem.Allocator) !void {
    var f2 = std.fs.createFileAbsolute("/tmp/db.trs", .{ .truncate = true }) catch |e| {
        std.log.err("unable to open temporary file in /tmp", .{});
        return e;
    };
    defer f2.close();

    database.seal(f2.writer(), pw) catch |e| {
        std.log.err("unable to persist database", .{});
        return e;
    };

    if (conf.db_path[0] == '~' and conf.db_path[1] == '/') {
        if (std.os.getenv("HOME")) |home| {
            var path = std.fmt.allocPrint(gpa, "{s}/{s}", .{ home, conf.db_path[2..] }) catch |e| {
                std.log.err("out of memory", .{});
                return e;
            };
            defer gpa.free(path);

            std.fs.copyFileAbsolute("/tmp/db.trs", path, .{}) catch |e| {
                std.log.err("unable to overwrite file `{s}`", .{conf.db_path});
                return e;
            };
        } else {
            std.log.err("no HOME path", .{});
            return error.NoHome;
        }
    } else if (conf.db_path[0] == '/') {
        std.fs.copyFileAbsolute("/tmp/db.trs", conf.db_path, .{}) catch |e| {
            std.log.err("unable to overwrite file `{s}`", .{conf.db_path});
            return e;
        };
    } else {
        std.log.err("support for file prefix not implemented yet!!!", .{});
        return error.InvalidFilePrefix;
    }
}

pub fn deinit(a: std.mem.Allocator) void {
    database.deinit();
    @memset(pw, 0);
    a.free(pw);
    pw = undefined;
    ts = null;
    uv_result = UvResult.Denied;
    up_result = null;
}

fn createDialog(a: std.mem.Allocator) !std.fs.File {
    var r1: std.ChildProcess.ExecResult = try std.ChildProcess.exec(.{
        .allocator = a,
        .argv = &.{
            "zenity",
            "--question",
            "--icon=/usr/local/bin/passkeez/passkeez.png",
            "--title=PassKeeZ: No database found",
            "--text=Do you want to create a new passkey database?",
        },
    });
    defer {
        a.free(r1.stdout);
        a.free(r1.stderr);
    }

    switch (r1.term.Exited) {
        0 => {},
        else => return error.CreateDbRejected,
    }

    outer: while (true) {
        var r2: std.ChildProcess.ExecResult = try std.ChildProcess.exec(.{
            .allocator = a,
            .argv = &.{
                "zenity",
                "--forms",
                "--title=PassKeeZ: New Database",
                "--text=Please choose a password (numbers, characters, symbols, NO \'|\'!)",
                "--add-password=Password",
                "--add-password=Repeat Password",
                "--ok-label=create",
            },
        });
        defer {
            a.free(r2.stdout);
            a.free(r2.stderr);
        }

        switch (r2.term.Exited) {
            0 => {
                std.log.info("{s}", .{r2.stdout});
                var iter = std.mem.split(u8, r2.stdout[0 .. r2.stdout.len - 1], "|");
                const pw1 = iter.next();
                const pw2 = iter.next();
                std.log.info("{any}, {any}", .{ pw1, pw2 });

                if (pw1 == null or pw2 == null or !std.mem.eql(u8, pw1.?, pw2.?)) {
                    const r = try std.ChildProcess.exec(.{
                        .allocator = a,
                        .argv = &.{ "zenity", "--error", "--text=Passwords do not match" },
                    });
                    defer {
                        a.free(r.stdout);
                        a.free(r.stderr);
                    }
                    continue :outer;
                }

                const f_db = try db.createFile(conf.db_path);
                errdefer f_db.close();

                var store = try tresor.Tresor.new(
                    1,
                    0,
                    .ChaCha20,
                    .None,
                    .Argon2id,
                    "PassKey",
                    "PassKeeZ",
                    a,
                    std.crypto.random,
                    std.time.milliTimestamp,
                );
                defer store.deinit();
                try store.seal(f_db.writer(), pw1.?);

                const r = try std.ChildProcess.exec(.{
                    .allocator = a,
                    .argv = &.{ "zenity", "--info", "--text=Database successfully create" },
                });
                defer {
                    a.free(r.stdout);
                    a.free(r.stderr);
                }

                return f_db;
            },
            else => return error.CreateDbRejected,
        }
    }
}
