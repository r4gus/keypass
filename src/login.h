#ifndef __LOGIN_H
#define __LOGIN_H

#include <gtk/gtk.h>

#define LOGIN_WIDGET_TYPE (login_widget_get_type())

G_DECLARE_FINAL_TYPE(LoginWidget, login_widget, LOGIN, WIDGET, GtkBox)

#endif
