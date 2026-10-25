#ifndef RUNNER_DESKTOP_BRIDGE_H_
#define RUNNER_DESKTOP_BRIDGE_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// The native side of lib/desktop/desktop_bridge.dart (channel
// "app/desktop"), as windows/runner/desktop_bridge.cpp on Windows: the
// window's close button, the tray icon (AppIndicator, loaded at run time;
// without it "hide" minimizes the window instead), notifications (the
// desktop's notification service over D-Bus), and the XDG autostart entry.
typedef struct _DesktopBridge DesktopBridge;

DesktopBridge* desktop_bridge_new(FlView* view, GtkWindow* window);

// The app's icon in the bundle (data/app_icon.png); g_free it.
gchar* app_icon_path();

// A second launch asked to bring the window up.
void desktop_bridge_activate(DesktopBridge* bridge);

#endif  // RUNNER_DESKTOP_BRIDGE_H_
