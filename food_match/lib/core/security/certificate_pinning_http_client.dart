import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';

import 'api_security_config.dart';

class CertificatePinningHttpClient {
  const CertificatePinningHttpClient._();

  static IOClient create() {
    ApiSecurityConfig.validateApiTransport();
    final HttpClient httpClient = HttpClient();
    if (ApiSecurityConfig.certificatePinningEnabled) {
      httpClient.badCertificateCallback = (X509Certificate certificate, String host, int port) {
        if (host != ApiSecurityConfig.productionApiHost) return false;
        if (kDebugMode) {
          debugPrint('[ApiSecurity] Rejected invalid certificate for $host:$port');
        }
        return false;
      };
    }
    return IOClient(httpClient);
  }
}
