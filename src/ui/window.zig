const gtk = @import("../gtk.zig");
const std = @import("std");

const windowDecl = @embedFile("./window.ui");

pub const Window = struct {
    win: [*c]gtk.GObject,
    header: struct {
        gears: [*c]gtk.GtkMenuButton,
    },
    stack: [*c]gtk.GtkStack,

    pub fn new() !Window {
        const builder = try gtk.builderAddFromString(windowDecl);
        defer gtk.g_object_unref(builder);

        const self = @This(){
            .win = gtk.gtk_builder_get_object(builder, "window"),
            .header = .{
                .gears = @ptrCast(gtk.gtk_builder_get_object(builder, "gears")),
            },
            .stack = @ptrCast(gtk.gtk_builder_get_object(builder, "stack")),
        };

        _ = gtk.g_signal_connect_(
            self.win,
            "destroy",
            @as(gtk.GCallback, @ptrCast(&gtk.gtk_main_quit)),
            null,
        );

        _ = gtk.gtk_stack_set_visible_child_name(self.stack, "login_screen");

        return self;
    }
};
