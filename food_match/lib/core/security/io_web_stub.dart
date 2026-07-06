class X509Certificate {
  const X509Certificate();
}

class HttpClient {
  bool Function(X509Certificate certificate, String host, int port)? badCertificateCallback;

  HttpClient();
}
