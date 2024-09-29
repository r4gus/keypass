const std = @import("std");
const cbor = @import("zbor");
const fido = @import("keylib");

/// Number of existing discoverable credentials present on the authenticator
existingResidentCredentialsCount: ?u32 = null,
/// Number of maximum possible remaining discoverable credentials which can be created on the authenticator
maxPossibleRemainingResidentCredentialsCount: ?u32 = null,
/// RP Information
rp: ?fido.common.RelyingParty = null,
/// RP ID SHA-256 hash
rpIDHash: ?[32]u8 = null,
/// total number of RPs present on the authenticator
totalRPs: ?u32 = null,
/// User Information
user: ?fido.common.User = null,
/// PublicKeyCredentialDescriptor
credentialID: ?fido.common.PublicKeyCredentialDescriptor = null,
/// Public key of the credential
publicKey: ?cbor.cose.Key = null,
/// Total number of credentials present on the authenticator for the RP in question
totalCredentials: ?u32 = null,
/// Credential protection policy
credProtect: ?fido.ctap.extensions.CredentialCreationPolicy = null,
/// Large blob encryption key
largeBlobKey: ?[]const u8 = null,

pub fn cborStringify(self: *const @This(), options: cbor.Options, out: anytype) !void {
    _ = options;

    try cbor.stringify(self, .{
        .field_settings = &.{
            .{ .name = "existingResidentCredentialsCount", .field_options = .{ .alias = "1", .serialization_type = .Integer } },
            .{ .name = "maxPossibleRemainingResidentCredentialsCount", .field_options = .{ .alias = "2", .serialization_type = .Integer } },
            .{ .name = "rp", .field_options = .{ .alias = "3", .serialization_type = .Integer } },
            .{ .name = "rpIDHash", .field_options = .{ .alias = "4", .serialization_type = .Integer } },
            .{ .name = "totalRPs", .field_options = .{ .alias = "5", .serialization_type = .Integer } },
            .{ .name = "user", .field_options = .{ .alias = "6", .serialization_type = .Integer } },
            .{ .name = "credentialID", .field_options = .{ .alias = "7", .serialization_type = .Integer } },
            .{ .name = "publicKey", .field_options = .{ .alias = "8", .serialization_type = .Integer } },
            .{ .name = "totalCredentials", .field_options = .{ .alias = "9", .serialization_type = .Integer } },
            .{ .name = "credProtect", .field_options = .{ .alias = "10", .serialization_type = .Integer }, .value_options = .{ .enum_serialization_type = .Integer } },
            .{ .name = "largeBlobKey", .field_options = .{ .alias = "11", .serialization_type = .Integer } },
        },
        .from_callback = true,
    }, out);
}

pub fn cborParse(item: cbor.DataItem, options: cbor.Options) !@This() {
    return try cbor.parse(@This(), item, .{
        .allocator = options.allocator,
        .from_callback = true, // prevent infinite loops
        .field_settings = &.{
            .{ .name = "existingResidentCredentialsCount", .field_options = .{ .alias = "1", .serialization_type = .Integer } },
            .{ .name = "maxPossibleRemainingResidentCredentialsCount", .field_options = .{ .alias = "2", .serialization_type = .Integer } },
            .{ .name = "rp", .field_options = .{ .alias = "3", .serialization_type = .Integer } },
            .{ .name = "rpIDHash", .field_options = .{ .alias = "4", .serialization_type = .Integer } },
            .{ .name = "totalRPs", .field_options = .{ .alias = "5", .serialization_type = .Integer } },
            .{ .name = "user", .field_options = .{ .alias = "6", .serialization_type = .Integer } },
            .{ .name = "credentialID", .field_options = .{ .alias = "7", .serialization_type = .Integer } },
            .{ .name = "publicKey", .field_options = .{ .alias = "8", .serialization_type = .Integer } },
            .{ .name = "totalCredentials", .field_options = .{ .alias = "9", .serialization_type = .Integer } },
            .{ .name = "credProtect", .field_options = .{ .alias = "10", .serialization_type = .Integer }, .value_options = .{ .enum_serialization_type = .Integer } },
            .{ .name = "largeBlobKey", .field_options = .{ .alias = "11", .serialization_type = .Integer } },
        },
    });
}
