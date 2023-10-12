#include <gtk/gtk.h>

#include "authenticator.h"
#include "authenticatorwin.h"

struct _AuthenticatorApp
{
    GtkApplication parent;
};

G_DEFINE_TYPE(AuthenticatorApp, authenticator_app, GTK_TYPE_APPLICATION);

static void
authenticator_app_init(AuthenticatorApp* app)
{
}

static void
about_activated (GSimpleAction *action,
                       GVariant      *parameter,
                       gpointer       app)
{
}

static void
quit_activated (GSimpleAction *action,
                GVariant      *parameter,
                gpointer       app)
{
  g_application_quit (G_APPLICATION (app));
}

static GActionEntry app_entries[] =
{
  { "about", about_activated, NULL, NULL, NULL },
  { "quit", quit_activated, NULL, NULL, NULL }
};

static void
authenticator_app_startup(GApplication* app)
{
    const char* quit_accels[2] = { "<Ctrl>Q", NULL };
    
    G_APPLICATION_CLASS(authenticator_app_parent_class)->startup(app);

    g_action_map_add_action_entries(G_ACTION_MAP(app), app_entries, G_N_ELEMENTS(app_entries), app);

    gtk_application_set_accels_for_action (GTK_APPLICATION (app), "app.quit", quit_accels);
}

static void
authenticator_app_activate(GApplication* app)
{
    AuthenticatorAppWindow *win;

    win = authenticator_app_window_new(AUTHENTICATOR_APP(app));
    gtk_window_present(GTK_WINDOW(win));
}

static void
authenticator_app_class_init(AuthenticatorAppClass* class)
{
    G_APPLICATION_CLASS (class)->startup = authenticator_app_startup;
    G_APPLICATION_CLASS (class)->activate = authenticator_app_activate;
}

AuthenticatorApp*
authenticator_app_new(void)
{
    return g_object_new(
        AUTHENTICATOR_APP_TYPE,
        "application-id", "de.thesugar.keypass",
        "flags", G_APPLICATION_HANDLES_OPEN,
        NULL);
}

