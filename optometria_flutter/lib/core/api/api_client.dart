import 'api_transport.dart';

class ApiClient {
  ApiClient({required this.baseUrl}) : _transport = createApiTransport();

  final String baseUrl;
  final ApiTransport _transport;

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
  }) {
    return _transport.send(
      baseUrl: baseUrl,
      method: 'GET',
      path: path,
      token: token,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return _transport.send(
      baseUrl: baseUrl,
      method: 'POST',
      path: path,
      body: body,
      token: token,
    );
  }
}
