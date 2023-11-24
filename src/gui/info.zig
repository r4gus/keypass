const dvui = @import("dvui");
const main = @import("../main.zig");

pub fn info_dialog() !void {
    var dialog_win = try dvui.floatingWindow(@src(), .{ .stay_above_parent = true, .modal = false, .open_flag = &main.show_dialog }, .{
        .corner_radius = dvui.Rect.all(0),
    });
    defer dialog_win.deinit();

    try dvui.windowHeader("About PassKeeZ", "", &main.show_dialog);
    try dvui.label(@src(), "About", .{}, .{ .font_style = .title_4 });

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "Website:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/r4gus/keypass", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/r4gus/keypass");
        }
    }

    try dvui.label(@src(), "PassKeeZ and keylib are distributed under the MIT license.", .{}, .{});
    try dvui.label(@src(), "Project Maintainers: David Sugar (r4gus)", .{}, .{});
    try dvui.label(@src(), "Special thanks to David Vanderson and\nthe whole Zig community.", .{}, .{});
    _ = dvui.spacer(@src(), .{}, .{ .expand = .vertical });
    try dvui.label(@src(), "Dependencies", .{}, .{ .font_style = .title_4 });

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "dvui:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/david-vanderson/dvui", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/david-vanderson/dvui");
        }
    }

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "keylib:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/r4gus/keylib", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/r4gus/keylib");
        }
    }

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "tresor:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/r4gus/tresor", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/r4gus/tresor");
        }
    }

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.label(@src(), "zbor:", .{}, .{});
        if (try dvui.labelClick(@src(), "https://github.com/r4gus/zbor", .{}, .{ .gravity_y = 0.5, .color_text = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } })) {
            try dvui.openURL("https://github.com/r4gus/zbor");
        }
    }
}
