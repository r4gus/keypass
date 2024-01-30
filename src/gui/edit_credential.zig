const std = @import("std");
const dvui = @import("dvui");
const main = @import("../main.zig");
const tresor = @import("tresor");
const db = @import("../db.zig");
const gui = @import("../gui.zig");
const create = @import("create.zig");
const style = @import("../style.zig");
const application_state = @import("../state.zig");

/// Dialog for updating a existing database
pub fn edit_credential_dialog(id: []const u8) !void {
    const S = struct {
        var toggle_danger: bool = false;
    };

    const hid = try std.fmt.allocPrint(main.gpa, "{s}", .{std.fmt.fmtSliceHexUpper(id)});
    defer main.gpa.free(hid);

    var dialog_win = try dvui.floatingWindow(@src(), .{ .stay_above_parent = true, .modal = false, .open_flag = &gui.edit_credential.show }, .{
        .corner_radius = dvui.Rect.all(0),
        .min_size_content = .{ .w = 400.0, .h = 300.0 },
    });

    defer dialog_win.deinit();
    try dvui.windowHeader("Edit", hid[hid.len - 12 ..], &gui.edit_credential.show);

    {
        var vbox = try dvui.box(@src(), .vertical, .{
            .expand = .horizontal,
            .margin = dvui.Rect{ .x = 7.0, .y = 0.0, .w = 7.0, .h = 0.0 },
            .padding = dvui.Rect.all(7),
        });
        defer vbox.deinit();

        {
            var hbox = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
            defer hbox.deinit();

            try dvui.label(@src(), "Identifier: {s}", .{hid}, .{ .gravity_y = 0.5 });
        }

        var vbox2 = try dvui.box(@src(), .vertical, .{
            .expand = .horizontal,
            .border = .{ .x = 1.0, .y = 1.0, .w = 1.0, .h = 1.0 },
            .color_border = dvui.Color{ .r = 255, .g = 0, .b = 0 },
            .background = null,
            .margin = .{ .x = 1.0, .y = 10.0, .w = 1.0, .h = 1.0 },
            .padding = .{ .x = 1.0, .y = 1.0, .w = 1.0, .h = 1.0 },
        });
        defer vbox2.deinit();

        try dvui.label(@src(), "Danger Zone", .{}, .{ .font_style = .title_4 });

        {
            var hbox = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
            defer hbox.deinit();

            try dvui.label(@src(), "Delete credential: ", .{}, .{ .gravity_y = 0.5 });
            if (try dvui.button(@src(), "delete", .{}, .{
                .gravity_y = 0.5,
                .color_fill = if (!S.toggle_danger) .{ .r = 128, .g = 128, .b = 128 } else style.err,
            })) {
                if (S.toggle_danger) {
                    // TODO: this is a workaround and will be removed in the future.
                    var index: usize = 0;
                    while (index < id.len and id[index] != 0) : (index += 1) {}

                    // The user has enabled the delete button
                    application_state.database.removeEntry(id[0..index]) catch {
                        try dvui.toast(@src(), .{ .message = "Unable to delete credential" });
                        S.toggle_danger = false;
                        gui.edit_credential.show = false;
                        return;
                    };

                    // persist change
                    application_state.writeDb(main.gpa) catch {
                        try dvui.toast(@src(), .{ .message = "Unable to update database" });
                        S.toggle_danger = false;
                        gui.edit_credential.show = false;
                        return;
                    };

                    S.toggle_danger = false;
                    gui.edit_credential.show = false;
                    try dvui.toast(@src(), .{ .message = "Credential successfully deleted" });
                    return;
                }
            }
            try dvui.checkbox(@src(), &S.toggle_danger, "unlock", .{ .gravity_x = 1.0, .gravity_y = 0.5 });
        }
    }
}
