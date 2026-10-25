import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow {
  private(set) var bridge: DesktopBridge?

  override func awakeFromNib() {
    let project = FlutterDartProject()
    // The Dart side reads --autostart and --data-dir from its arguments.
    project.dartEntrypointArguments = Array(CommandLine.arguments.dropFirst())
    let flutterViewController = FlutterViewController(project: project)
    self.contentViewController = flutterViewController
    self.title = "Firefox VPN"
    self.setContentSize(NSSize(width: 820, height: 680))
    // The smallest window the pages are laid out for.
    self.contentMinSize = NSSize(width: 720, height: 560)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    bridge = DesktopBridge(
      messenger: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}

/// The native side of lib/desktop/desktop_bridge.dart (channel
/// "app/desktop"), as windows/runner/desktop_bridge.cpp and
/// linux/runner/desktop_bridge.cc are elsewhere: the window's close button,
/// the menu bar icon and its menu, notifications, and starting at sign-in
/// (a LaunchAgent). While the window is hidden the app lives in the menu
/// bar only, without a Dock icon.
class DesktopBridge: NSObject, NSWindowDelegate, UNUserNotificationCenterDelegate {
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?
  private var statusItem: NSStatusItem?
  private var iconPath = ""
  private var allowClose = false

  private static let label = "com.arman.firefoxvpn"

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    channel = FlutterMethodChannel(name: "app/desktop", binaryMessenger: messenger)
    self.window = window
    super.init()
    window.delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    UNUserNotificationCenter.current().delegate = self
    NotificationCenter.default.addObserver(
      self, selector: #selector(didFinishLaunching(_:)),
      name: NSApplication.didFinishLaunchingNotification, object: nil)
  }

  @objc private func didFinishLaunching(_ notification: Notification) {
    // Started at sign-in: stay in the menu bar.
    if CommandLine.arguments.contains("--autostart") {
      hide()
    }
    // Opening the app again (Finder, the Dock, Spotlight) brings the
    // window up, also from the menu bar.
    NSAppleEventManager.shared().setEventHandler(
      self, andSelector: #selector(reopen(_:withReplyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEReopenApplication))
  }

  @objc private func reopen(
    _ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor
  ) {
    show()
    channel.invokeMethod("shown", arguments: nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "setTray":
      setTray(args)
    case "notify":
      notify(title: args["title"] as? String ?? "", body: args["body"] as? String ?? "")
    case "setAutostart":
      setAutostart(args["enabled"] as? Bool ?? false)
    case "show":
      show()
    case "hide":
      hide()
    case "quit":
      allowClose = true
      if let item = statusItem {
        NSStatusBar.system.removeStatusItem(item)
      }
      result(nil)
      NSApp.terminate(nil)
      return
    default:
      result(FlutterMethodNotImplemented)
      return
    }
    result(nil)
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if allowClose {
      return true
    }
    channel.invokeMethod("closeRequested", arguments: nil)
    return false
  }

  private func show() {
    NSApp.setActivationPolicy(.regular)
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func hide() {
    window?.orderOut(nil)
    if statusItem != nil {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  // The menu bar icon: the state's icon and the menu, which a click opens,
  // as menu bar icons do.
  private func setTray(_ args: [String: Any]) {
    if statusItem == nil {
      statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    }
    guard let item = statusItem else {
      return
    }
    let path = args["icon"] as? String ?? ""
    if path != iconPath, let image = NSImage(contentsOfFile: path) {
      image.size = NSSize(width: 18, height: 18)
      item.button?.image = image
      iconPath = path
    }
    item.button?.toolTip = args["tooltip"] as? String
    let menu = buildMenu(args["items"] as? [[String: Any]] ?? [])
    menu.userInterfaceLayoutDirection =
      (args["rtl"] as? Bool ?? false) ? .rightToLeft : .leftToRight
    item.menu = menu
  }

  private func buildMenu(_ entries: [[String: Any]]) -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false
    for entry in entries {
      if entry["separator"] as? Bool ?? false {
        menu.addItem(.separator())
        continue
      }
      let item = NSMenuItem(title: entry["label"] as? String ?? "", action: nil, keyEquivalent: "")
      item.isEnabled = entry["enabled"] as? Bool ?? true
      item.state = (entry["checked"] as? Bool ?? false) ? .on : .off
      if let children = entry["children"] as? [[String: Any]], !children.isEmpty {
        item.submenu = buildMenu(children)
      } else {
        item.tag = entry["id"] as? Int ?? 0
        item.target = self
        item.action = #selector(menuItemChosen(_:))
      }
      menu.addItem(item)
    }
    return menu
  }

  @objc private func menuItemChosen(_ sender: NSMenuItem) {
    if sender.tag > 0 {
      channel.invokeMethod("trayMenu", arguments: sender.tag)
    }
  }

  // A notification; clicking it opens the window, as the menu's Open does.
  private func notify(title: String, body: String) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert]) { granted, _ in
      guard granted else {
        return
      }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      center.add(
        UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    DispatchQueue.main.async {
      self.channel.invokeMethod("trayClicked", arguments: nil)
    }
    completionHandler()
  }

  // The LaunchAgent that starts this copy of the app at sign-in, in the
  // menu bar.
  private func setAutostart(_ enabled: Bool) {
    let url = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/LaunchAgents/\(DesktopBridge.label).plist")
    guard enabled, let executable = Bundle.main.executablePath else {
      try? FileManager.default.removeItem(at: url)
      return
    }
    let agent: [String: Any] = [
      "Label": DesktopBridge.label,
      "ProgramArguments": [executable, "--autostart"],
      "RunAtLoad": true,
      "ProcessType": "Interactive",
    ]
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = try? PropertyListSerialization.data(
      fromPropertyList: agent, format: .xml, options: 0)
    {
      try? data.write(to: url)
    }
  }
}
