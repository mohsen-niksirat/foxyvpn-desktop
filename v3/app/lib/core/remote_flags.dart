import 'dart:typed_data';

import 'core_api.dart';

/// The flags of Mozilla's locations, which the app carries in
/// assets/flags; the core has the same ones.
const bundledFlags = {
  'ar', 'at', 'au', 'be', 'bg', 'br', 'ca', 'cl', 'co', 'de', 'dk', //
  'es', 'fi', 'fr', 'gb', 'gh', 'ie', 'it', 'jp', 'kr', 'mx', 'my', //
  'nl', 'no', 'nz', 'pe', 'ph', 'pt', 'se', 'sg', 'th', 'us', 'za', //
};

/// Flags the app does not carry (a location Mozilla added later), asked
/// from the core once per run; the core downloads and keeps them.
abstract final class RemoteFlags {
  static CoreApi? _api;
  static final _cache = <String, Future<Uint8List?>>{};

  /// The core to ask; another core (a restart) starts a fresh cache, so a
  /// flag it could not get before is asked again.
  static void use(CoreApi api) {
    if (identical(api, _api)) return;
    _api = api;
    _cache.clear();
  }

  /// The flag's SVG, or null when the core has none or does not answer.
  static Future<Uint8List?> load(String code) {
    final api = _api;
    if (api == null) return Future.value();
    return _cache.putIfAbsent(code, () => api.flag(code));
  }
}
