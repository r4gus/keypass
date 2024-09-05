const std = @import("std");
const ccdb = @import("ccdb");
const db = @import("db.zig");
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
pub var database: ccdb.Db = undefined;

pub var uv_result = UvResult.Denied;
pub var up_result: ?UpResult = null;

var ts: ?i64 = null;
const tout1: i64 = 10; // seconds
const tout2: i64 = 60; // seconds

pub fn init(a: std.mem.Allocator) !void {
    conf = db.Config.load(a) catch |e| blk: {
        std.log.err("unable to load configuration file ({any})", .{e});
        db.Config.create(a) catch |e2| {
            std.log.err("unable to create configuration file ({any})", .{e2});
            return e2;
        };
        const conf_ = db.Config.load(a) catch |e2| {
            std.log.err("unable to load configuration file after new database creation ({any})", .{e2});
            return e2;
        };
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

    const f = db.openFile(conf.db_path) catch |e1| blk: {
        std.log.warn("unable to open database ({any})", .{e1});

        break :blk createDialog(a) catch |e2| {
            std.log.err("db creation failed ({any})", .{e2});
            return e2;
        };
    };
    f.close();

    outer: while (i > 0) : (i -= 1) {
        var password = std.process.Child.run(.{
            .allocator = a,
            .argv = &.{
                "zigenity",
                "--password",
                "--window-icon=/usr/share/passkeez/passkeez.png",
                "--title=PassKeeZ: Unlock Database",
                "--ok-label=Unlock",
                "--timeout=60",
            },
        }) catch |e| {
            std.log.err("unable to execute zigenity ({any})", .{e});
            return e;
        };
        defer {
            @memset(password.stdout, 0);
            a.free(password.stdout);
            @memset(password.stderr, 0);
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
                    const r = std.process.Child.run(.{
                        .allocator = a,
                        .argv = &.{
                            "zigenity",
                            "--question",
                            "--window-icon=/usr/share/passkeez/passkeez.png",
                            "--icon=/usr/share/passkeez/passkeez-error.png",
                            "--text=Credential database decryption failed",
                            "--title=PassKeeZ: Wrong Password",
                            "--ok-label=Ok",
                            "--switch-cancel",
                            "--timeout=15",
                        },
                    }) catch |e2| {
                        std.log.err("unable to execute zigenity ({any})", .{e2});
                        return e2;
                    };
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
        const r = std.process.Child.run(.{
            .allocator = a,
            .argv = &.{
                "zigenity",
                "--question",
                "--window-icon=/usr/share/passkeez/passkeez.png",
                "--icon=/usr/share/passkeez/passkeez-error.png",
                "--text=Too many incorrect password attempts",
                "--title=PassKeeZ: Authentication failed",
                "--ok-label=Ok",
                "--switch-cancel",
                "--timeout=15",
            },
        }) catch |e| {
            std.log.err("unable to execute zigenity ({any})", .{e});
            return e;
        };
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

    const raw = database.seal(gpa) catch |e| {
        std.log.err("unable to seal database ({any})", .{e});
        return e;
    };
    defer {
        @memset(raw, 0);
        gpa.free(raw);
    }

    f2.writer().writeAll(raw) catch |e| {
        std.log.err("unable to persist database ({any})", .{e});
        return e;
    };

    if (conf.db_path[0] == '~' and conf.db_path[1] == '/') {
        if (std.c.getenv("HOME")) |home| {
            // TODO: check home
            const path = std.fmt.allocPrint(gpa, "{s}/{s}", .{ home[0..std.zig.c_builtins.__builtin_strlen(home)], conf.db_path[2..] }) catch |e| {
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
    const r1 = std.process.Child.run(.{
        .allocator = a,
        .argv = &.{
            "zigenity",
            "--question",
            "--window-icon=/usr/share/passkeez/passkeez.png",
            "--icon=/usr/share/passkeez/passkeez-question.png",
            "--title=PassKeeZ: No Database",
            "--text=Do you want to create a new passkey database?",
        },
    }) catch |e| {
        std.log.err("unable to execute zigenity ({any})", .{e});
        return e;
    };

    defer {
        a.free(r1.stdout);
        a.free(r1.stderr);
    }

    switch (r1.term.Exited) {
        0 => {},
        else => return error.CreateDbRejected,
    }

    outer: while (true) {
        var r2 = std.process.Child.run(.{
            .allocator = a,
            .argv = &.{
                "zigenity",
                "--password",
                "--window-icon=/usr/share/passkeez/passkeez.png",
                "--title=PassKeeZ: New Database",
                "--text=Please choose a password",
                "--ok-label=Create",
                "--cancel-label=Cancel",
            },
        }) catch |e| {
            std.log.err("unable to execute zigenity ({any})", .{e});
            return e;
        };
        defer {
            a.free(r2.stdout);
            a.free(r2.stderr);
        }

        switch (r2.term.Exited) {
            0 => {
                std.log.info("{s}", .{r2.stdout});
                const pw1 = r2.stdout[0 .. r2.stdout.len - 1];

                if (pw1.len < 8) {
                    const r = std.process.Child.run(.{
                        .allocator = a,
                        .argv = &.{
                            "zigenity",
                            "--question",
                            "--window-icon=/usr/share/passkeez/passkeez.png",
                            "--icon=/usr/share/passkeez/passkeez-error.png",
                            "--text=Password must be 8 characters long",
                            "--title=PassKeeZ: Error",
                            "--timeout=15",
                            "--switch-cancel",
                            "--ok-label=Ok",
                        },
                    }) catch |e| {
                        std.log.err("unable to execute zigenity ({any})", .{e});
                        return e;
                    };
                    defer {
                        a.free(r.stdout);
                        a.free(r.stderr);
                    }
                    continue :outer;
                }

                const f_db = db.createFile(conf.db_path) catch |e| {
                    std.log.err("unable to create new database file ({any})", .{e});
                    return e;
                };
                errdefer f_db.close();

                var store = ccdb.Db.new("PassKeeZ", "Passkeys", .{}, a) catch |e| {
                    std.log.err("unable to create database ({any})", .{e});
                    return e;
                };
                defer store.deinit();
                store.setKey(pw1) catch |e| {
                    std.log.err("unable to set database key ({any})", .{e});
                    return e;
                };
                const raw = store.seal(a) catch |e| {
                    std.log.err("unable to seal database ({any})", .{e});
                    return e;
                };
                defer {
                    @memset(raw, 0);
                    a.free(raw);
                }

                f_db.writer().writeAll(raw) catch |e| {
                    std.log.err("unable to write database ({any})", .{e});
                    return e;
                };

                const r = std.process.Child.run(.{
                    .allocator = a,
                    .argv = &.{
                        "zigenity",
                        "--question",
                        "--window-icon=/usr/share/passkeez/passkeez.png",
                        "--icon=/usr/share/passkeez/passkeez-ok.png",
                        "--text=Database successfully create",
                        "--title=PassKeeZ: Success",
                        "--timeout=15",
                        "--switch-cancel",
                        "--ok-label=Ok",
                    },
                }) catch |e| {
                    std.log.err("unable to execute zigenity ({any})", .{e});
                    return e;
                };
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

pub fn credentialFromEntry(entry: *const ccdb.Entry) !keylib.ctap.authenticator.Credential {
    if (entry.user == null) return error.MissingUser;
    if (entry.url == null) return error.MissingRelyingParty;
    if (entry.key == null) return error.MissingKey;
    if (entry.tags == null) return error.MissingPolicy;

    const policy = blk: for (entry.tags.?) |tag| {
        if (tag.len < 8) continue;
        if (!std.mem.eql(u8, "policy:", tag[0..7])) continue;

        if (keylib.ctap.extensions.CredentialCreationPolicy.fromString(tag[7..])) |p| {
            break :blk p;
        } else {
            return error.MissingPolicy;
        }
    } else {
        return error.MissingPolicy;
    };

    return .{
        .id = (try keylib.common.dt.ABS64B.fromSlice(entry.uuid[0..])).?,
        .user = try keylib.common.User.new(entry.user.?.id.?, entry.user.?.name, entry.user.?.display_name),
        .rp = try keylib.common.RelyingParty.new(entry.url.?, null),
        .sign_count = if (entry.times.cnt) |cnt| cnt else 0,
        .key = entry.key.?,
        .created = entry.times.creat,
        .discoverable = true,
        .policy = policy,
    };
}
