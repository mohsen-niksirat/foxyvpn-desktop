import 'dart:io';

/// Ports the user may choose: above the privileged range.
bool validPort(int port) => port >= 1024 && port <= 65535;

/// The port of a listen address such as `127.0.0.1:10810`; null without one.
int? portOf(String listen) {
  final colon = listen.lastIndexOf(':');
  return colon < 0 ? null : int.tryParse(listen.substring(colon + 1));
}

/// [listen] with its port replaced; the host stays.
String withPort(String listen, int port) {
  final colon = listen.lastIndexOf(':');
  final host = colon < 0 ? '127.0.0.1' : listen.substring(0, colon);
  return '${host.isEmpty ? '127.0.0.1' : host}:$port';
}

/// A loopback port nothing listens on, near [after] so it is easy to
/// remember; a port from the system when none of those is free.
Future<int> findFreePort(int after) async {
  for (var port = after + 1; port <= after + 200 && port <= 65535; port++) {
    if (await isFree(port)) return port;
  }
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// Whether a loopback listener could take [port] now.
Future<bool> isFree(int port) async {
  try {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await socket.close();
    return true;
  } on SocketException {
    return false;
  }
}
