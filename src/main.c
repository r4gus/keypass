#include <gtk/gtk.h>

#include "authenticator.h"

int
main (int argc, char *argv[])
{
  return g_application_run (G_APPLICATION (authenticator_app_new ()), argc, argv);
}

