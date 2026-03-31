import 'dart:io';

class ConnectivityHelper {
  /// Quick check: can we reach the server?
  static Future<bool> hasConnection(String host) async {
    try {
      final List<InternetAddress> result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
