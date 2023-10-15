#include <gtk/gtk.h>

#include "login.h"

struct _LoginWidget
{
    GtkBox parent;

    GtkPasswordEntry* pwentry;
    GtkWidget* pwsubmit;
};

G_DEFINE_TYPE(LoginWidget, login_widget, GTK_TYPE_BOX);

static void
login_widget_init(LoginWidget* self)
{
    gtk_widget_init_template(GTK_WIDGET(self));

    // It is now possible to access self->entry and self->button
}

static void
login_widget_class_init(LoginWidgetClass* class)
{
    gtk_widget_class_set_template_from_resource(GTK_WIDGET_CLASS(class), "/de/thesugar/keypass/ui/login.ui");

    gtk_widget_class_bind_template_child (GTK_WIDGET_CLASS (class), LoginWidget, pwentry);
    gtk_widget_class_bind_template_child (GTK_WIDGET_CLASS (class), LoginWidget, pwsubmit);

    gtk_widget_class_set_layout_manager_type(GTK_WIDGET_CLASS(class), GTK_TYPE_BOX_LAYOUT);
}
