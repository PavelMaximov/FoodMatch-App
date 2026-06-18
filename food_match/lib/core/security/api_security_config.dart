import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';

class ApiSecurityConfig {
  const ApiSecurityConfig._();

  static const String productionApiHost = String.fromEnvironment(
    'PRODUCTION_API_HOST',
    defaultValue: 'api.foodmatch.app',
  );

  static const bool allowInsecureHttpForDev = bool.fromEnvironment(
    'ALLOW_INSECURE_HTTP_FOR_DEV',
    defaultValue: true,
  );

  static const bool requireHttpsInRelease = bool.fromEnvironment(
    'REQUIRE_HTTPS_IN_RELEASE',
    defaultValue: true,
  );

  static const bool _pinningFlag = bool.fromEnvironment(
    'CERTIFICATE_PINNING_ENABLED',
    defaultValue: false,
  );

  static const String _pinsCsv = String.fromEnvironment(
    'CERTIFICATE_PINS',
    defaultValue: '',
  );

  static bool get isProductionBuild => kReleaseMode;
  static Uri get apiBaseUri => Uri.parse(ApiConstants.baseUrl);
  static List<String> get certificatePins => _pinsCsv.split(',').map((String pin) => pin.trim()).where((String pin) => pin.isNotEmpty).toList(growable: false);
  static bool get isHttpsApi => apiBaseUri.scheme.toLowerCase() == 'https';
  static bool get isProductionHostConfigured => productionApiHost.isNotEmpty && apiBaseUri.host == productionApiHost;
  static bool get certificatePinningEnabled => _pinningFlag && isHttpsApi && isProductionHostConfigured && certificatePins.isNotEmpty;

  static void validateApiTransport() {
    final Uri baseUri = apiBaseUri;
    final String scheme = baseUri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw StateError('Unsupported API URL scheme for FoodMatch API.');
    }
    if (scheme == 'http' && isProductionBuild && requireHttpsInRelease) {
      throw StateError('Insecure FoodMatch API URL blocked in release builds. Configure an HTTPS base URL before shipping.');
    }
    if (scheme == 'http' && !allowInsecureHttpForDev) {
      throw StateError('Insecure FoodMatch API URL is disabled by configuration.');
    }
    if (_pinningFlag && !certificatePinningEnabled) {
      debugPrint('[ApiSecurity] Certificate pinning requested but not enabled. Pinning requires HTTPS, host=$productionApiHost, and non-empty CERTIFICATE_PINS.');
    }
  }
}
