import 'api_transport_io.dart'
    if (dart.library.html) 'api_transport_web.dart';

abstract class ApiTransport {
  Future<Map<String, dynamic>> send({
    required String baseUrl,
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? token,
  });
}

ApiTransport createApiTransport() => createTransport();
