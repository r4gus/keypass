const std = @import("std");
const keylib = @import("keylib");
const Credential = keylib.ctap.authenticator.Credential;

pub const ccdb = @import("database/ccdb.zig");

const Self = @This();

pub const Error = error{
    OutOfMemory,
    FileNotFound,
    FileError,
    WouldBlock,
    Other,
    NoHome,
    DatabaseError,
    UnsupportedItem,
    InvalidPairCount,
    NoKey,
    UnexpectedlyLongCidOrIv,
    InvalidCipherSuite,
    InvalidNonceLength,
    InvalidKeyLength,
    DoesNotExist,
};

path: []const u8,
pw: []const u8,
db: ?*anyopaque = null,
allocator: std.mem.Allocator,

init: *const fn (*Self) Error!void,

deinit: *const fn (*const Self) void,

save: *const fn (*const Self, std.mem.Allocator) Error!void,

getCredential: *const fn (
    *const Self,
    rpId: ?[]const u8,
    rpIdHash: ?[32]u8,
    idx: *usize,
) Error!Credential,

setCredential: *const fn (
    *const Self,
    data: Credential,
) Error!void,
