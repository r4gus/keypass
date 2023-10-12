#ifndef __AUTHENTICATORAPP_H
#define __AUTHENTICATORAPP_H

#include <gtk/gtk.h>

#define AUTHENTICATOR_APP_TYPE (authenticator_app_get_type())

G_DECLARE_FINAL_TYPE(AuthenticatorApp, authenticator_app, AUTHENTICATOR, APP, GtkApplication)
AuthenticatorApp* authenticator_app_new(void);

#endif
