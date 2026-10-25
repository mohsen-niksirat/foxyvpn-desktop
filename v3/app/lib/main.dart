import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';
import 'core/android_core.dart';
import 'core/core_api.dart';
import 'core/core_controller.dart';
import 'core/updates.dart';
import 'core/core_process.dart';
import 'core/ports.dart';
import 'desktop/desktop_integration.dart';
import 'ui/app.dart';

/// The desktop app starts the core as its child process (`-app`) and stops
/// it on quit. Arguments: `--data-dir=<path>` (default: see
/// [CoreLocator.dataDir]) and `--core=<path>` (default:
/// [CoreProcess.executableFrom], `core\firefox-vpn-core.exe` beside the app).
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) return runAndroid();
  final dataDir = CoreLocator.dataDir(args);
  final settings = await AppSettings.load(dataDir);
  final process = CoreProcess(
    executable: CoreProcess.executableFrom(args),
    dataDir: dataDir,
  );
  final core = CoreController(
    process.connect,
    moveStoppedCore: (port) async {
      final listen = await CoreLocator.dashboardListen(dataDir);
      await CoreLocator.setDashboardListen(dataDir, withPort(listen, port));
      process.retryNow();
    },
    retryStoppedCore: () async => process.retryNow(),
  )..start();
  // Back in front: the core tries again at once, not after a wait.
  AppLifecycleListener(onResume: core.retryNow);
  final navigatorKey = GlobalKey<NavigatorState>();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    DesktopIntegration(
      core: core,
      settings: settings,
      process: process,
      navigatorKey: navigatorKey,
      startHidden: args.contains('--autostart'),
      manageAutostart: !args.any((a) => a.startsWith('--data-dir=')),
    ).start();
  }
  Updates.start(core, settings);
  runApp(VpnApp(core: core, settings: settings, navigatorKey: navigatorKey));
}

/// Android: the core runs in this app's process, in a foreground service
/// that keeps the proxy up while the UI is closed.
Future<void> runAndroid() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge to edge: the home page's hero colors the status bar.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  final dataDir = await AndroidCore.dataDir();
  final settings = await AppSettings.load(dataDir);
  await AndroidCore.loadMode();
  final core = CoreController(
    AndroidCore(dataDir).connect,
    turnOn: AndroidCore.setOn,
  )..start();
  AppLifecycleListener(onResume: core.retryNow);
  Updates.start(core, settings);
  runApp(VpnApp(core: core, settings: settings));
}
