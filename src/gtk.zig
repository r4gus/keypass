pub usingnamespace @cImport({
    @cInclude("gtk/gtk.h");
});

const c = @cImport({
    @cInclude("gtk/gtk.h");
});

pub fn print_hello(_: *c.GtkWidget, _: c.gpointer) void {
    c.g_print("Hello World\n");
}

/// Could not get `g_signal_connect` to work. Zig says "use of undeclared identifier". Reimplemented here
pub fn g_signal_connect_(instance: c.gpointer, detailed_signal: [*c]const c.gchar, c_handler: c.GCallback, data: c.gpointer) c.gulong {
    var zero: u32 = 0;
    const flags: *c.GConnectFlags = @as(*c.GConnectFlags, @ptrCast(&zero));
    return c.g_signal_connect_data(instance, detailed_signal, c_handler, data, null, flags.*);
}

/// Could not get `g_signal_connect_swapped` to work. Zig says "use of undeclared identifier". Reimplemented here
pub fn g_signal_connect_swapped_(instance: c.gpointer, detailed_signal: [*c]const c.gchar, c_handler: c.GCallback, data: c.gpointer) c.gulong {
    return c.g_signal_connect_data(instance, detailed_signal, c_handler, data, null, c.G_CONNECT_SWAPPED);
}

/// Construct a GtkBuilder instance and load our UI description from a string.
pub fn builderAddFromString(s: []const u8) !*c.GtkBuilder {
    const builder: *c.GtkBuilder = c.gtk_builder_new();
    const s_: [*c]const u8 = s.ptr;
    var err: [*c]c.GError = null;

    if (c.gtk_builder_add_from_string(builder, s_, s.len, &err) == 0) {
        c.g_printerr("Error loading embedded builder: %s\n", err.*.message);
        c.g_clear_error(&err);
        c.g_object_unref(builder);
        return error.Loading;
    }

    return builder;
}
