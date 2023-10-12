#ifndef __AUTHENTICATORAPPWIN_H
#define __AUTHENTICATORAPPWIN_H

#include <gtk/gtk.h>
#include "authenticator.h"

#define AUTHENTICATOR_APP_WINDOW_TYPE (authenticator_app_window_get_type())

G_DECLARE_FINAL_TYPE(AuthenticatorAppWindow, authenticator_app_window, AUTHENTICATOR, APP_WINDOW, GtkApplicationWindow)
AuthenticatorAppWindow* authenticator_app_window_new(AuthenticatorApp* app);
void authenticator_app_window_open(AuthenticatorAppWindow* win, GFile* file);

#endif

