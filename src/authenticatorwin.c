#include <gtk/gtk.h>

#include "authenticator.h"
#include "authenticatorwin.h"

struct _AuthenticatorAppWindow
{
    GtkApplicationWindow parent;

    GtkWidget* gears;
};

G_DEFINE_TYPE(AuthenticatorAppWindow, authenticator_app_window, GTK_TYPE_APPLICATION_WINDOW);

static void
authenticator_app_window_init(AuthenticatorAppWindow* win)
{
    GtkBuilder *builder;
    GMenuModel *menu;

    gtk_widget_init_template(GTK_WIDGET(win));

    builder = gtk_builder_new_from_resource ("/de/thesugar/keypass/menu.ui");
    menu = G_MENU_MODEL (gtk_builder_get_object (builder, "menu"));
    gtk_menu_button_set_menu_model (GTK_MENU_BUTTON (win->gears), menu);
    g_object_unref (builder);
}

static void
authenticator_app_window_class_init(AuthenticatorAppWindowClass* class)
{
    gtk_widget_class_set_template_from_resource(GTK_WIDGET_CLASS(class), "/de/thesugar/keypass/window.ui");
    gtk_widget_class_bind_template_child (GTK_WIDGET_CLASS (class), AuthenticatorAppWindow, gears);
}

AuthenticatorAppWindow*
authenticator_app_window_new(AuthenticatorApp* app)
{
    return g_object_new(AUTHENTICATOR_APP_WINDOW_TYPE, "application", app, NULL);
}

void
authenticator_app_window_open(
    AuthenticatorAppWindow* win,
    GFile* file
)
{
}
