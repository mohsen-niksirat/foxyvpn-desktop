#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "desktop_bridge.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  // [instance] identifies this copy for a second launch's activate request;
  // [start_hidden] keeps the window in the tray (started with Windows).
  FlutterWindow(const flutter::DartProject& project, WPARAM instance,
                bool start_hidden);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  WPARAM instance_;
  bool start_hidden_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The close button and the tray icon, driven from Dart.
  std::unique_ptr<DesktopBridge> bridge_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
