const std = @import("std");
const cbor = @import("zbor");
const keylib = @import("keylib");
const application_state = @import("../state.zig");
const main = @import("../main.zig");
const dvui = @import("dvui");

pub fn main_frame() !void {
    if (application_state.database.data.entries) |*entries| {
        if (entries.len > 1) {
            for (entries.*, 0..) |*entry, i| {
                if (entry.getField("Data", std.time.milliTimestamp())) |data| {
                    var buffer: [1024]u8 = .{0} ** 1024;
                    const slice = try std.fmt.hexToBytes(&buffer, data);

                    const cred = cbor.parse(
                        keylib.ctap.authenticator.Credential,
                        try cbor.DataItem.new(slice),
                        .{ .allocator = main.gpa },
                    ) catch {
                        continue;
                    };
                    defer cred.deinit(main.gpa);

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
                                    var rps = try main.gpa.alloc(u8, cred.rp.id.len + 8);
                                    defer main.gpa.free(rps);
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
                        if (try dvui.button(@src(), "Delete", .{}, .{
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
