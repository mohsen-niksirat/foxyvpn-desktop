#include <cstring>

#include "my_application.h"

int main(int argc, char** argv) {
  // A copy started with its own data folder (development and tests) runs
  // beside the installed one.
  gboolean unique = TRUE;
  for (int i = 1; i < argc; i++) {
    if (strncmp(argv[i], "--data-dir=", 11) == 0) {
      unique = FALSE;
    }
  }
  g_autoptr(MyApplication) app = my_application_new(unique);
  return g_application_run(G_APPLICATION(app), argc, argv);
}
