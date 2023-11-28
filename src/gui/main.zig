const std = @import("std");
const cbor = @import("zbor");
const keylib = @import("keylib");
const application_state = @import("../state.zig");
const main = @import("../main.zig");
const dvui = @import("dvui");
const gui = @import("../gui.zig");

pub fn main_frame() !void {
    const S = struct {
        var search_string: [256]u8 = .{0} ** 256;

        pub fn getSearchString() []const u8 {
            return search_string[0..main.slen(&search_string)];
        }
    };
    var cred_counter: usize = 0;

    {
        var scroll = try dvui.scrollArea(@src(), .{}, .{ .expand = .both, .color_style = .window });
        defer scroll.deinit();

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

                        // Filter credentials using search string
                        const needle = S.getSearchString();
                        var match: bool = true;
                        if (needle.len > 0) blk: {
                            match = false;
                            if (cred.user.name) |name| {
                                if (std.mem.indexOf(u8, name, needle) != null) {
                                    match = true;
                                    break :blk;
                                }
                            }
                            if (cred.user.displayName) |name| {
                                if (std.mem.indexOf(u8, name, needle) != null) {
                                    match = true;
                                    break :blk;
                                }
                            }
                            if (std.mem.indexOf(u8, cred.rp.id, needle) != null) {
                                match = true;
                                break :blk;
                            }
                        }

                        if (!match) continue;

                        // We count the displayed credentials so we can display the number
                        // at the bottom of the page.
                        cred_counter += 1;

                        var outer_box = try dvui.box(@src(), .horizontal, .{
                            .margin = dvui.Rect{ .x = 8.0, .y = 8.0, .w = 8.0 },
                            .padding = dvui.Rect.all(8),
                            .background = true,
                            .expand = .horizontal,
                            .id_extra = i,
                        });
                        defer outer_box.deinit();

                        try dvui.icon(@src(), "key", dvui.entypo.key, .{ .gravity_y = 0.5, .min_size_content = .{ .h = 24 }, .margin = dvui.Rect{ .w = 4.0 } });

                        {
                            var box = try dvui.box(@src(), .vertical, .{
                                .expand = .horizontal,
                                .id_extra = i,
                            });
                            defer box.deinit();

                            {
                                {
                                    var hbox = try dvui.box(@src(), .horizontal, .{});
                                    defer hbox.deinit();

                                    try dvui.label(@src(), "URL:", .{}, .{});
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
                                try dvui.label(@src(), "Username: {s}", .{if (cred.user.displayName) |dn| blk: {
                                    break :blk dn;
                                } else if (cred.user.name) |n| blk: {
                                    break :blk n;
                                } else blk: {
                                    break :blk "?";
                                }}, .{ .gravity_y = 0.5 });
                            }
                        }

                        if (try dvui.buttonIcon(
                            @src(),
                            "cog",
                            dvui.entypo.cog,
                            .{},
                            .{
                                .gravity_y = 0.5,
                                .corner_radius = dvui.Rect.all(0),
                                .min_size_content = .{ .h = 24 },
                                .background = false,
                            },
                        )) {
                            if (gui.edit_credential.id) |id| {
                                main.gpa.free(id);
                            }
                            gui.edit_credential.id = try main.gpa.dupe(u8, cred.id);
                            gui.edit_credential.show = true;
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

    {
        var box = try dvui.box(@src(), .horizontal, .{
            .gravity_y = 1.0,
            .margin = dvui.Rect{ .y = 8.0 },
            .padding = dvui.Rect.all(8),
            .background = true,
            .expand = .horizontal,
        });
        defer box.deinit();

        try dvui.label(@src(), "{d} {s}", .{
            cred_counter,
            if (cred_counter == 1) "Credential" else "Credentials",
        }, .{
            .gravity_y = 0.5,
        });

        var search = try dvui.textEntry(@src(), .{
            .text = &S.search_string,
            .password_char = null,
        }, .{
            .corner_radius = dvui.Rect.all(0),
            .gravity_x = 1.0,
            .gravity_y = 0.5,
        });
        search.deinit();
    }
}
