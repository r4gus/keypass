const std = @import("std");
const keylib = @import("keylib");
const cbor = @import("zbor");
const uhid = @import("uhid");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const State = @import("state.zig");

var initialized = false;

pub fn main() !void {
    State.init(allocator) catch |e| {
        std.log.err("Unable to initialize application ({any})", .{e});
        return std.os.exit(1);
    };

    // The Auth struct is the most important part of your authenticator. It defines
    // its capabilities and behavior.
    var auth = keylib.ctap.authenticator.Auth{
        // The callbacks are the interface between the authenticator and the rest of the application (see below).
        .callbacks = callbacks,
        // The commands map from a command code to a command function. All functions have the
        // same interface and you can implement your own to extend the authenticator beyond
        // the official spec, e.g. add a command to store passwords.
        .commands = &.{
            .{ .cmd = 0x01, .cb = keylib.ctap.commands.authenticator.authenticatorMakeCredential },
            .{ .cmd = 0x02, .cb = keylib.ctap.commands.authenticator.authenticatorGetAssertion },
            .{ .cmd = 0x04, .cb = keylib.ctap.commands.authenticator.authenticatorGetInfo },
            .{ .cmd = 0x06, .cb = keylib.ctap.commands.authenticator.authenticatorClientPin },
            //.{ .cmd = 0x0b, .cb = keylib.ctap.commands.authenticator.authenticatorSelection },
        },
        // The settings are returned by a getInfo request and describe the capabilities
        // of your authenticator. Make sure your configuration is valid based on the
        // CTAP2 spec!
        .settings = .{
            // Those are the FIDO2 spec you support
            .versions = &.{ .FIDO_2_0, .FIDO_2_1 },
            // The extensions are defined as strings which should make it easy to extend
            // the authenticator (in combination with a new command).
            .extensions = &.{"credProtect"},
            // This should be unique for all models of the same authenticator.
            .aaguid = "\x73\x79\x63\x2e\x70\x61\x73\x73\x6b\x65\x65\x7a\x2e\x6f\x72\x67".*,
            .options = .{
                // We don't support the credential management command. If you want to
                // then you need to implement it yourself and add it to commands and
                // set this flag to true.
                .credMgmt = false,
                // We support discoverable credentials, a.k.a resident keys, a.k.a passkeys
                .rk = true,
                // We support built in user verification (see the callback below)
                .uv = true,
                // This is a platform authenticator even if we use usb for ipc
                .plat = true,
                // We don't support client pin but you could also add the command
                // yourself and set this to false (not initialized) or true (initialized).
                .clientPin = null,
                // We support pinUvAuthToken
                .pinUvAuthToken = true,
                // If you want to enforce alwaysUv you also have to set this to true.
                .alwaysUv = true,
            },
            // The pinUvAuth protocol to support. This library implements V1 and V2.
            .pinUvAuthProtocols = &.{.V2},
            // The transports your authenticator supports.
            .transports = &.{.usb},
            // The algorithms you support.
            .algorithms = &.{.{ .alg = .Es256 }},
            .firmwareVersion = 0x0036,
            .remainingDiscoverableCredentials = 100,
        },
        // Here we initialize the pinUvAuth token data structure wich handles the generation
        // and management of pinUvAuthTokens.
        .token = keylib.ctap.pinuv.PinUvAuth.v2(std.crypto.random),
        // Here we set the supported algorithm. You can also implement your
        // own and add them here.
        .algorithms = &.{
            keylib.ctap.crypto.algorithms.Es256,
        },
        // This allocator is used to allocate memory and has to be the same
        // used for the callbacks.
        .allocator = allocator,
        // A function to get the epoch time as i64.
        .milliTimestamp = std.time.milliTimestamp,
        // A cryptographically secure random number generator
        .random = std.crypto.random,
        // If you don't want to increment the sign counts
        // of credentials (e.g. because you sync them between devices)
        // set this to true.
        .constSignCount = true,
    };

    // Here we instantiate a CTAPHID handler.
    var ctaphid = keylib.ctap.transports.ctaphid.authenticator.CtapHid.init(allocator, std.crypto.random);
    defer ctaphid.deinit();

    // We use the uhid module on linux to simulate a USB device. If you use
    // tinyusb or something similar you have to adapt the code.
    var u = try uhid.Uhid.open();
    defer u.close();

    // This is the main loop
    while (true) {
        State.update(allocator);

        // We read in usb packets with a size of 64 bytes.
        var buffer: [64]u8 = .{0} ** 64;
        if (u.read(&buffer)) |packet| {
            // Those packets are passed to the CTAPHID handler who assembles
            // them into a CTAPHID message.
            var response = ctaphid.handle(packet);
            // Once a message is complete (or an error has occured) you
            // get a response.
            if (response) |*res| blk: {
                var skip = false;

                switch (res.cmd) {
                    .cbor => {
                        // We have to handle this here as we don't need to
                        // decrypt the database for this
                        if (res._data[0] == 0x0b) { // authenticator selection
                            res._data[0] = @intFromEnum(authenticatorSelection());
                            res.len = 1;
                            skip = true;
                        }
                    },
                    else => {},
                }

                if (!skip) {
                    State.authenticate(allocator) catch {
                        std.log.err("authentication failed", .{});
                        res._data[0] = 0x3f;
                        res.len = 1;
                        skip = true;
                    };
                }

                if (!skip) {
                    if (!initialized) {
                        try auth.init();
                        initialized = true;
                    }

                    switch (res.cmd) {
                        // Here we check if its a cbor message and if so, pass
                        // it to the handle() function of our authenticator.
                        .cbor => {
                            var out: [7609]u8 = undefined;
                            const r = auth.handle(&out, res.getData());
                            std.mem.copy(u8, res._data[0..r.len], r);
                            res.len = r.len;
                        },
                        else => {},
                    }
                }

                var iter = res.iterator();
                // Here we iterate over the response packets of our authenticator.
                while (iter.next()) |p| {
                    u.write(p) catch {
                        break :blk;
                    };
                }
            }
        }
        std.time.sleep(10000000);
    }
}

// /////////////////////////////////////////
// Data
// /////////////////////////////////////////

const Data = struct {
    rp: []const u8,
    id: []const u8,
    data: []const u8,
};

// For this example we use a volatile storage solution for our credentials.
var data_set = std.ArrayList(Data).init(allocator);

// /////////////////////////////////////////
// Auth
//
// Below you can see all the callbacks you have to implement
// (that are expected by the default command functions). Make
// sure you allocate memory with the same allocator that you
// passed to the Auth sturct.
//
// How you check user presence, conduct user verification or
// store the credentials is up to you.
// /////////////////////////////////////////

const UpResult = keylib.ctap.authenticator.callbacks.UpResult;
const UvResult = keylib.ctap.authenticator.callbacks.UvResult;
const Error = keylib.ctap.authenticator.callbacks.Error;

pub fn authenticatorSelection() keylib.ctap.StatusCodes {
    const r = std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{
            "zigenity",
            "--question",
            "--window-icon=/usr/share/passkeez/passkeez.png",
            "--icon=/usr/share/passkeez/passkeez-question.png",
            "--text=Do you want to use PassKeeZ as your authenticator?",
            "--title=Authenticator Selection",
            "--timeout=15",
        },
    }) catch {
        std.log.err("select: unable to create select dialog", .{});
        return .ctap2_err_operation_denied;
    };
    defer {
        allocator.free(r.stdout);
        allocator.free(r.stderr);
    }

    switch (r.term.Exited) {
        0 => return .ctap1_err_success,
        5 => return .ctap2_err_user_action_timeout,
        else => return .ctap2_err_operation_denied,
    }
}

//pub fn getInfo(
//    auth: *keylib.ctap.authenticator.Auth,
//    out: []u8,
//) usize {
//    var arr = std.ArrayList(u8).init(allocator);
//    defer arr.deinit();
//
//    cbor.stringify(auth.settings, .{}, arr.writer()) catch {
//        out[0] = @intFromEnum(keylib.ctap.StatusCodes.ctap1_err_other);
//        return 1;
//    };
//
//    out[0] = @intFromEnum(keylib.ctap.StatusCodes.ctap1_err_success);
//    @memcpy(out[1 .. arr.items.len + 1], arr.items);
//    return arr.items.len + 1;
//}

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

    return State.uv_result;
}

pub fn my_up(
    /// Information about the context (e.g., make credential)
    info: [*c]const u8,
    /// Information about the user (e.g., `David Sugar (david@example.com)`)
    user: [*c]const u8,
    /// Information about the relying party (e.g., `Github (github.com)`)
    rp: [*c]const u8,
) callconv(.C) UpResult {
    _ = user;
    _ = info;

    if (State.up_result) |r| return r;

    const text = std.fmt.allocPrint(allocator, "--text=Do you want to log in to {s}?", .{
        if (rp != null) rp[0..strlen(rp)] else "website",
    }) catch {
        std.log.err("up: unable to allocate memory for text", .{});
        return UpResult.Denied;
    };
    defer allocator.free(text);

    const r = std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{
            "zigenity",
            "--question",
            "--window-icon=/usr/local/bin/passkeez/passkeez.png",
            "--icon=/usr/local/bin/passkeez/passkeez-question.png",
            text,
            "--title=PassKeeZ: Authentication Request",
            "--timeout=30",
        },
    }) catch {
        std.log.err("up: unable to create up dialog", .{});
        return UpResult.Denied;
    };
    defer {
        allocator.free(r.stdout);
        allocator.free(r.stderr);
    }

    switch (r.term.Exited) {
        0 => return UpResult.Accepted,
        5 => return UpResult.Timeout,
        else => return UpResult.Denied,
    }
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
        if (State.database.getEntry(id[0..strlen(id)])) |*e| {
            if (e.*.getField("Data", std.time.microTimestamp())) |data| {
                var d = allocator.alloc(u8, data.len + 1) catch {
                    std.log.err("out of memory", .{});
                    return Error.OutOfMemory;
                };
                @memcpy(d[0..data.len], data);
                d[data.len] = 0;
                //var d = gpa.dupeZ(u8, data) catch {
                //    std.log.err("out of memory", .{});
                //    return Error.OutOfMemory;
                //};

                var x = allocator.alloc([*c]u8, 2) catch {
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
        var arr = std.ArrayList([*c]u8).init(allocator);
        if (State.database.getEntries(
            &.{.{ .key = "Url", .value = rp[0..strlen(rp)] }},
            allocator,
        )) |entries| {
            for (entries) |*e| {
                if (e.*.getField("Data", std.time.microTimestamp())) |data| {
                    var d = allocator.dupeZ(u8, data) catch {
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
    if (State.database.getEntry(id[0..strlen(id)])) |*e| {
        e.*.updateField("Data", data[0..strlen(data)], std.time.milliTimestamp()) catch {
            std.log.err("unable to update field", .{});
            return Error.Other;
        };
    } else {
        var e = State.database.createEntry(id[0..strlen(id)]) catch {
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

        State.database.addEntry(e) catch {
            std.log.err("unable to add entry to database", .{});
            e.deinit();
            return Error.Other;
        };
    }

    // persist data
    State.writeDb(allocator) catch {
        return Error.Other;
    };

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

// MISC

pub fn strlen(s: [*c]const u8) usize {
    var i: usize = 0;
    while (s[i] != 0) : (i += 1) {}
    return i;
}
