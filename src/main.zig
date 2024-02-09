const gtk = @import("gtk.zig");
const std = @import("std");

const builderDecl = @embedFile("./ui/builder.ui");
const gearsDecl = @embedFile("./ui/gears.ui");

const Window = @import("ui/window.zig").Window;
const gears = @import("ui/gears.zig");

pub fn main() !u8 {
    gtk.gtk_init(0, null);

    const window = try Window.new();
    try gears.init(&window);

    gtk.gtk_main();

    return 0;
}
