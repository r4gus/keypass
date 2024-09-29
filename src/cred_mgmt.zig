const std = @import("std");
const cbor = @import("zbor");
const keylib = @import("keylib");
const Request = @import("cred_mgmt/Request.zig");
const Response = @import("cred_mgmt/Response.zig");

pub fn authenticatorCredentialManagement(
    auth: *keylib.ctap.authenticator.Auth,
    request: []const u8,
    out: *std.ArrayList(u8),
) keylib.ctap.StatusCodes {
    const di = cbor.DataItem.new(request) catch {
        return .ctap2_err_invalid_cbor;
    };

    const cmReq = cbor.parse(Request, di, .{}) catch |err| {
        std.log.err("authenticatorCredentialManagement: Unable to parse arguments ({any})", .{err});
        return .ctap2_err_invalid_cbor;
    };

    var status: keylib.ctap.StatusCodes = .ctap1_err_success;
    const res = switch (cmReq.subCommand) {
        .getCredsMetadata => getCredsMetadata(auth, &cmReq, &status),
        else => error.ctap2_err_other,
    } catch {
        return .ctap1_err_other;
    };

    if (status != .ctap1_err_success) return status;

    cbor.stringify(res, .{}, out.writer()) catch {
        std.log.err("credentialManagement: cbor encoding error", .{});
        return keylib.ctap.StatusCodes.ctap1_err_other;
    };

    return status;
}

pub fn getCredsMetadata(auth: *keylib.ctap.authenticator.Auth, req: *const Request, status: *keylib.ctap.StatusCodes) Response {
    if (req.pinUvAuthParam == null) {
        status.* = .ctap2_err_missing_parameter;
        return .{};
    }
    if (req.pinUvAuthProtocol == null) {
        status.* = .ctap2_err_missing_parameter;
        return .{};
    }
    if (req.pinUvAuthProtocol.? != auth.token.version) {
        status.* = .ctap1_err_invalid_parameter;
        return .{};
    }
    if (!auth.token.verify_token("\x01", req.pinUvAuthParam.?.get())) {
        status.* = .ctap2_err_pin_auth_invalid;
        return .{};
    }

    var credential_count: u32 = 1;
    _ = auth.callbacks.read_first(null, null) catch {
        credential_count -= 1;
    };

    if (credential_count > 0) {
        while (true) {
            _ = auth.callbacks.read_next() catch {
                break;
            };
            credential_count += 1;
        }
    }

    return .{
        .existingResidentCredentialsCount = credential_count,
        // This number is aribitrary for the given platform authenticator
        // and always greater than zero!
        .maxPossibleRemainingResidentCredentialsCount = 100,
    };
}
