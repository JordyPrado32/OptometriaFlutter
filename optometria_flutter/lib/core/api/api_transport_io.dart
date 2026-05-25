import 'dart:convert';
import 'dart:io';

import 'api_exception.dart';
import 'api_transport.dart';

class IoApiTransport implements ApiTransport {
  @override
  Future<Map<String, dynamic>> send({
    required String baseUrl,
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);

    try {
      final request = await client.openUrl(
        method,
        Uri.parse('$baseUrl$path'),
      );

      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      if (token != null && token.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final raw = await response.transform(utf8.decoder).join();
      return _parseResponse(response.statusCode, raw);
    } on SocketException {
      throw const ApiException(
        message:
            'No se pudo conectar al backend. Revisa que Node este corriendo y la URL base sea correcta.',
      );
    } on HandshakeException {
      throw const ApiException(
        message: 'Fallo de seguridad en la conexion con el backend.',
      );
    } on FormatException {
      throw const ApiException(
        message: 'La respuesta del backend no tiene un formato JSON valido.',
      );
    } finally {
      client.close(force: true);
    }
  }
}

ApiTransport createTransport() => IoApiTransport();

Map<String, dynamic> _parseResponse(int statusCode, String raw) {
  final parsed = _decodeJsonObject(raw);

  if (statusCode < 200 || statusCode >= 300) {
    final errors = (parsed['errors'] is List)
        ? (parsed['errors'] as List).map((item) => '$item').toList()
        : const <String>[];

    throw ApiException(
      message: parsed['message']?.toString() ?? 'Error de servidor.',
      statusCode: statusCode,
      errors: errors,
    );
  }

  return parsed;
}

Map<String, dynamic> _decodeJsonObject(String raw) {
  if (raw.trim().isEmpty) {
    return <String, dynamic>{};
  }

  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }

  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry('$key', value));
  }

  throw const FormatException('Expected a JSON object response.');
}
