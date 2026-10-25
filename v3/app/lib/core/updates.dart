import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_info.dart';
import '../app_settings.dart';
import '../platform.dart';
import 'android_core.dart';
import 'core_api.dart';
import 'core_controller.dart';
import 'models.dart';

/// The release's APKs, one per processor type (scripts/build-android.ps1,
/// .github/workflows/build.yml); others get the universal one.
const _apkAbis = {'arm64-v8a', 'armeabi-v7a', 'x86_64'};

/// Where the Download button goes: the release's file for this copy of the
/// app, which the browser downloads at once (no page to choose from): on a
/// phone the APK for its processor; on Windows the installer for an
/// installed copy (its uninstaller is beside it) and the zip for a portable
/// one; on macOS the disk image; on Linux the archive for the processor.
Future<String> downloadUrl(Release release) async {
  if (!release.url.contains('/releases/tag/')) return release.url;
  final String name;
  if (Platform.isAndroid) {
    final abi = await AndroidCore.abi().catchError((Object _) => '');
    name = apkName(abi);
  } else if (Platform.isWindows) {
    final dir = File(Platform.resolvedExecutable).parent.path;
    final installed = File('$dir${Platform.pathSeparator}unins000.exe');
    name = windowsName(installed: installed.existsSync());
  } else if (Platform.isMacOS) {
    name = 'macOS.dmg';
  } else if (Platform.isLinux) {
    name = linuxName(Platform.version);
  } else {
    return release.url;
  }
  return releaseFileUrl(release.url, name);
}

/// The APK's name part for processor [abi].
String apkName(String abi) =>
    'Android-${_apkAbis.contains(abi) ? abi : 'universal'}.apk';

/// The Windows file's name part: the installer, or the portable zip.
String windowsName({required bool installed}) =>
    installed ? 'Windows-Setup-x64.exe' : 'Windows-x64.zip';

/// The Linux archive's name part for the processor in Dart's
/// [platformVersion] ("... on "linux_arm64"").
String linuxName(String platformVersion) =>
    'Linux-${platformVersion.contains('arm64') ? 'arm64' : 'amd64'}.tar.gz';

/// The file `Firefox-VPN-<version>-[name]` in the release whose page is
/// [releaseUrl] (".../releases/tag/v1.2.3"): its versioned name, so the
/// downloaded file says which version it is.
String releaseFileUrl(String releaseUrl, String name) {
  final tag = releaseUrl.substring(releaseUrl.lastIndexOf('/') + 1);
  final version = tag.replaceFirst(RegExp('^[vV]'), '');
  return '${releaseUrl.replaceFirst('/releases/tag/', '/releases/download/')}'
      '/Firefox-VPN-$version-$name';
}

/// The APK for processor [abi] in the release whose page is [releaseUrl].
String apkUrl(String releaseUrl, String abi) =>
    releaseFileUrl(releaseUrl, apkName(abi));

/// Opens the release's download (see [downloadUrl]).
Future<void> openDownload(Release release) async =>
    openUrl(await downloadUrl(release));

/// The local proxy for GitHub requests, on networks that block GitHub: the
/// VPN's own while it runs without a proxy login; null otherwise.
String? updateProxy(CoreStatus? status) {
  final proxy = status?.proxy;
  if (status?.state.phase != Phase.running || proxy == null) return null;
  if (proxy.loginRequired) return null;
  return CoreLocator.listenUri(proxy.listen).authority;
}

/// Looks for a newer release on GitHub every 5 days: the app looks a minute
/// after it starts, and then every hour, whether 5 days have passed since
/// the last look that worked. What it finds is kept in the settings, so the
/// home page shows it after a restart too; the computer also shows a
/// notification while the window is in the tray. The About page looks at
/// once, whenever asked.
abstract final class Updates {
  /// How long a successful look holds.
  static const every = Duration(days: 5);

  /// The newer release, once one was found.
  static final available = ValueNotifier<Release?>(null);

  static Timer? _timer;
  static CoreController? _core;
  static AppSettings? _settings;

  static void start(CoreController core, AppSettings settings) {
    if (githubRepo.isEmpty || _timer != null) return;
    _core = core;
    _settings = settings;
    // A version found earlier, unless this app is already that one.
    if (newerVersion(settings.updateVersion, appVersion)) {
      available.value = Release(settings.updateVersion, settings.updateUrl);
    }
    Timer(const Duration(minutes: 1), _due);
    _timer = Timer.periodic(const Duration(hours: 1), (_) => _due());
  }

  static Future<void> _due() async {
    final last = _settings?.updateCheckedAt;
    if (last != null && DateTime.now().difference(last) < every) return;
    try {
      found(await checkForUpdate(proxy: updateProxy(_core?.status)));
    } on Exception {
      // No network, or GitHub not reachable: the next hour tries again.
    }
  }

  /// The result of a look that worked, here or on the About page: a newer
  /// [release], or null when this version is the newest.
  static void found(Release? release) {
    available.value = release;
    _settings?.update(
      updateCheckedAt: DateTime.now(),
      updateVersion: release?.version ?? '',
      updateUrl: release?.url ?? '',
    );
  }
}
