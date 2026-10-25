#ifndef RUNNER_DESKTOP_BRIDGE_H_
#define RUNNER_DESKTOP_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

// The window's close button and the tray icon, for Dart (method channel
// "app/desktop"). Dart decides what closing does and builds the tray menu;
// this class only carries out the Win32 side.
//
// Dart to native: setTray {icon, tooltip, rtl, items: [{id, label, enabled,
// checked, separator, children}]}, notify {title, body}, setAutostart
// {enabled, command}, openUrl (an http or https link, as a string), show,
// hide, quit. An item with children is a submenu.
// Native to Dart: closeRequested, trayClicked, trayMenu (the item id),
// shown (a second launch brought the window up).
class DesktopBridge {
 public:
  DesktopBridge(flutter::BinaryMessenger* messenger, HWND window,
                WPARAM instance);
  ~DesktopBridge();

  DesktopBridge(const DesktopBridge&) = delete;
  DesktopBridge& operator=(const DesktopBridge&) = delete;

  // Handles the window messages the bridge owns; nullopt for the others.
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam,
                                       LPARAM lparam);

 private:
  struct MenuEntry {
    int id = 0;
    std::wstring label;
    bool enabled = true;
    bool checked = false;
    bool separator = false;
    std::vector<MenuEntry> children;
  };

  static std::vector<MenuEntry> ParseMenu(const flutter::EncodableList& items);
  static HMENU BuildMenu(const std::vector<MenuEntry>& entries);

  void HandleCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetTray(const flutter::EncodableMap& args);
  void UpdateIcon();
  void LoadTrayIcon();
  static bool TaskbarIsDark();
  void RemoveIcon();
  void ShowMenu();
  void Notify(const std::wstring& title, const std::wstring& body);
  void ShowWindowNow();
  bool OpenUrl(const std::wstring& url);
  static void SetAutostart(bool enabled, const std::wstring& command);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  // Set by "quit": the next WM_CLOSE really closes the window.
  bool allow_close_ = false;
  bool icon_added_ = false;
  HICON icon_ = nullptr;
  std::wstring icon_path_;
  // The icon the app asked for; a name-dark sibling is used on a dark
  // taskbar.
  std::wstring requested_icon_;
  std::wstring tooltip_;
  bool rtl_ = false;
  std::vector<MenuEntry> menu_;
  // Explorer sends it after a restart; the icon must be added again.
  UINT taskbar_created_;
  // A second launch broadcasts it with this copy's instance key.
  UINT activate_;
  WPARAM instance_;
};

#endif  // RUNNER_DESKTOP_BRIDGE_H_
