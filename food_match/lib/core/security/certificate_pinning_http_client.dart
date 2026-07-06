import 'package:http/http.dart' as http;

import 'api_security_config.dart';

// Conditional imports for web compatibility.
import 'certificate_pinning_http_client_io.dart'
    if (dart.library.html) 'certificate_pinning_http_client_web.dart';

class CertificatePinningHttpClient {
  const CertificatePinningHttpClient._();

  static http.Client create() {
    ApiSecurityConfig.validateApiTransport();
    return createHttpClient();
  }
}
