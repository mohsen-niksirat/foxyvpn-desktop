import 'package:flutter/services.dart';

/// A tray menu entry; ids start at 1. An entry with [children] is a
/// submenu.
class TrayItem {
  const TrayItem(
    this.id,
    this.label, {
    this.enabled = true,
    this.checked = false,
    this.children = const [],
  }) : separator = false;

  const TrayItem.submenu(this.label, this.children, {this.enabled = true})
    : id = 0,
      checked = false,
      separator = false;

  const TrayItem.separator()
    : id = 0,
      label = '',
      enabled = false,
      checked = false,
      separator = true,
      children = const [];

  final int id;
  final String label;
  final bool enabled;
  final bool checked;
  final bool separator;
  final List<TrayItem> children;

  Map<String, Object> toMap() => {
    'id': id,
    'label': label,
    'enabled': enabled,
    'checked': checked,
    'separator': separator,
    if (children.isNotEmpty) 'children': [for (final c in children) c.toMap()],
  };

  /// Identifies what the menu shows, to skip redundant updates.
  String get signature => separator
      ? '-'
      : '$id:$label:$enabled:$checked(${children.map((c) => c.signature).join(',')})';
}

/// The native side of the window's close button and the tray icon
/// (windows/runner/desktop_bridge.cpp, linux/runner/desktop_bridge.cc, and
/// DesktopBridge in macos/Runner/MainFlutterWindow.swift; channel
/// "app/desktop").
class DesktopBridge {
  DesktopBridge({
    required this.onCloseRequested,
    required this.onTrayClicked,
    required this.onTrayMenu,
    required this.onShown,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'closeRequested':
          onCloseRequested();
        case 'trayClicked':
          onTrayClicked();
        case 'trayMenu':
          onTrayMenu(call.arguments as int);
        case 'shown':
          onShown();
      }
    });
  }

  static const _channel = MethodChannel('app/desktop');

  final void Function() onCloseRequested;
  final void Function() onTrayClicked;
  final void Function(int id) onTrayMenu;

  /// A second launch brought the window up.
  final void Function() onShown;

  Future<void> setTray({
    required String icon,
    required String tooltip,
    required List<TrayItem> items,
    bool rtl = false,
  }) => _channel.invokeMethod('setTray', {
    'icon': icon,
    'tooltip': tooltip,
    'rtl': rtl,
    'items': [for (final i in items) i.toMap()],
  });

  /// A notification from the tray icon (a Windows toast; elsewhere, the
  /// system's notifications).
  Future<void> notify(String title, String body) =>
      _channel.invokeMethod('notify', {'title': title, 'body': body});

  /// Starts [command] at sign-in (the current user's Run key; on Linux, an
  /// XDG autostart entry; on macOS, a LaunchAgent for this app), or not.
  Future<void> setAutostart({required bool enabled, required String command}) =>
      _channel.invokeMethod('setAutostart', {
        'enabled': enabled,
        'command': command,
      });

  /// Opens an http or https [url] in the default browser through the
  /// shell (Windows only; the runner refuses other schemes).
  static Future<void> openUrl(String url) =>
      _channel.invokeMethod('openUrl', url);

  Future<void> show() => _channel.invokeMethod('show');

  Future<void> hide() => _channel.invokeMethod('hide');

  /// Removes the tray icon and closes the window, which ends the app.
  Future<void> quit() => _channel.invokeMethod('quit');
}
