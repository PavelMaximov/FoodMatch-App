import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'api_security_config.dart';

http.Client createHttpClient() {
  ApiSecurityConfig.validateApiTransport();
  final HttpClient httpClient = HttpClient();
  if (ApiSecurityConfig.certificatePinningEnabled) {
    httpClient.badCertificateCallback = (X509Certificate certificate, String host, int port) {
      if (host != ApiSecurityConfig.productionApiHost) return false;
      return false;
    };
  }
  return IOClient(httpClient);
}
