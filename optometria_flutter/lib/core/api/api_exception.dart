class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errors = const [],
  });

  final String message;
  final int? statusCode;
  final List<String> errors;

  @override
  String toString() {
    if (errors.isEmpty) {
      return message;
    }

    return '$message\n${errors.join('\n')}';
  }
}
