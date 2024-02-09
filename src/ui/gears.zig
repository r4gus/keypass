const gtk = @import("../gtk.zig");
const std = @import("std");
const Window = @import("window.zig").Window;

const gearsDecl = @embedFile("./gears.ui");

pub fn init(win: *const Window) !void {
    const builder = try gtk.builderAddFromString(gearsDecl);
    defer gtk.g_object_unref(builder);

    var menu = gtk.gtk_builder_get_object(builder, "menu");
    _ = gtk.gtk_menu_button_set_menu_model(
        win.header.gears,
        @as([*c]gtk.GMenuModel, @ptrCast(menu)),
    );
}
