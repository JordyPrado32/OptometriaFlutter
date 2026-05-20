import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'api_exception.dart';
import 'api_transport.dart';

class WebApiTransport implements ApiTransport {
  @override
  Future<Map<String, dynamic>> send({
    required String baseUrl,
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final request = html.HttpRequest();
    final completer = Completer<Map<String, dynamic>>();

    request
      ..open(method, '$baseUrl$path')
      ..setRequestHeader('Accept', 'application/json')
      ..setRequestHeader('Content-Type', 'application/json');

    if (token != null && token.trim().isNotEmpty) {
      request.setRequestHeader('Authorization', 'Bearer $token');
    }

    request.onLoadEnd.listen((_) {
      if (request.status == 0) {
        if (!completer.isCompleted) {
          completer.completeError(
            const ApiException(
              message:
                  'No se pudo conectar al backend desde el navegador. Revisa que Node este corriendo y que CORS permita esta solicitud.',
            ),
          );
        }
        return;
      }

      try {
        final result = _parseResponse(
          request.status ?? 0,
          request.responseText ?? '',
        );

        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } on ApiException catch (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      } on FormatException {
        if (!completer.isCompleted) {
          completer.completeError(
            const ApiException(
              message:
                  'La respuesta del backend no tiene un formato JSON valido.',
            ),
          );
        }
      }
    });

    request.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          const ApiException(
            message:
                'No se pudo conectar al backend desde el navegador. Revisa que Node este corriendo y que CORS permita esta solicitud.',
          ),
        );
      }
    });

    request.send(body == null ? null : jsonEncode(body));

    return completer.future;
  }
}

ApiTransport createTransport() => WebApiTransport();

Map<String, dynamic> _parseResponse(int statusCode, String raw) {
  final parsed = raw.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(raw) as Map<String, dynamic>;

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
