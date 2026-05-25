import '../../core/api/api_client.dart';
import '../../core/api/api_config.dart';

class AuthService {
  AuthService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<HealthStatus> checkHealth() async {
    final json = await _apiClient.get('/health');
    return HealthStatus(
      ok: json['ok'] == true,
      databaseStatus: json['db']?.toString() ?? 'unknown',
    );
  }

  Future<PasswordPolicy> getPasswordPolicy() async {
    final json = await _apiClient.get('/auth/password-policy');
    return PasswordPolicy.fromJson(json);
  }

  Future<SessionResponse> getSession(String token) async {
    final json = await _apiClient.get('/auth/session', token: token);
    return SessionResponse.fromJson(json);
  }

  Future<MessageResponse> register(RegisterRequest request) async {
    final json = await _apiClient.post(
      '/auth/register',
      body: request.toJson(),
    );
    return MessageResponse(
      message: json['message']?.toString() ?? 'Usuario registrado.',
    );
  }

  Future<LoginResponse> login(LoginRequest request) async {
    final json = await _apiClient.post(
      '/auth/login',
      body: request.toJson(),
    );
    return LoginResponse.fromJson(json);
  }

  Future<LoginResponse> verifyTwoFactor(TwoFactorLoginRequest request) async {
    final json = await _apiClient.post(
      '/auth/verify-2fa-login',
      body: request.toJson(),
    );
    return LoginResponse.fromJson(json);
  }

  Future<MessageResponse> requestPasswordReset(String identifier) async {
    final json = await _apiClient.post(
      '/auth/request-password-reset',
      body: {'identifier': identifier},
    );
    return MessageResponse(
      message: json['message']?.toString() ?? 'Recuperacion generada.',
      resetToken: json['resetToken']?.toString(),
      expiresInMinutes: _readNullableInt(json['expiresInMinutes']),
    );
  }

  Future<MessageResponse> resetPassword(ResetPasswordRequest request) async {
    final json = await _apiClient.post(
      '/auth/reset-password',
      body: request.toJson(),
    );
    return MessageResponse(
      message:
          json['message']?.toString() ?? 'Contrasena restablecida correctamente.',
    );
  }

  Future<MessageResponse> changePassword(
    ChangePasswordRequest request,
    String token,
  ) async {
    final json = await _apiClient.post(
      '/auth/change-password',
      body: request.toJson(),
      token: token,
    );
    return MessageResponse(
      message:
          json['message']?.toString() ?? 'Contrasena actualizada correctamente.',
    );
  }

  Future<TwoFactorSetupResponse> setupTwoFactor(String token) async {
    final json = await _apiClient.post('/auth/2fa/setup', token: token);
    return TwoFactorSetupResponse.fromJson(json);
  }

  Future<MessageResponse> confirmTwoFactor(String otp, String token) async {
    final json = await _apiClient.post(
      '/auth/2fa/confirm',
      body: {'otp': otp},
      token: token,
    );
    return MessageResponse(
      message: json['message']?.toString() ?? '2FA activado correctamente.',
    );
  }
}

class HealthStatus {
  const HealthStatus({
    required this.ok,
    required this.databaseStatus,
  });

  final bool ok;
  final String databaseStatus;
}

class PasswordPolicy {
  const PasswordPolicy({
    required this.minLength,
    required this.requiresUppercase,
    required this.requiresLowercase,
    required this.requiresNumber,
    required this.requiresSpecialChar,
    required this.disallowPersonalData,
    required this.expiresInDays,
    required this.maxFailedAttempts,
    required this.lockoutMinutes,
    required this.twoFactorSupported,
  });

  factory PasswordPolicy.fromJson(Map<String, dynamic> json) {
    return PasswordPolicy(
      minLength: _readInt(json['minLength'], 12),
      requiresUppercase: json['requiresUppercase'] == true,
      requiresLowercase: json['requiresLowercase'] == true,
      requiresNumber: json['requiresNumber'] == true,
      requiresSpecialChar: json['requiresSpecialChar'] == true,
      disallowPersonalData: json['disallowPersonalData'] == true,
      expiresInDays: _readInt(json['expiresInDays'], 90),
      maxFailedAttempts: _readInt(json['maxFailedAttempts'], 5),
      lockoutMinutes: _readInt(json['lockoutMinutes'], 15),
      twoFactorSupported: json['twoFactorSupported'] == true,
    );
  }

  final int minLength;
  final bool requiresUppercase;
  final bool requiresLowercase;
  final bool requiresNumber;
  final bool requiresSpecialChar;
  final bool disallowPersonalData;
  final int expiresInDays;
  final int maxFailedAttempts;
  final int lockoutMinutes;
  final bool twoFactorSupported;
}

class RegisterRequest {
  const RegisterRequest({
    required this.nombres,
    required this.apellidos,
    required this.email,
    required this.usuario,
    required this.telefono,
    required this.password,
  });

  final String nombres;
  final String apellidos;
  final String email;
  final String usuario;
  final String telefono;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'nombres': nombres,
      'apellidos': apellidos,
      'email': email.trim().isEmpty ? null : email.trim(),
      'usuario': usuario,
      'telefono': telefono.trim().isEmpty ? null : telefono.trim(),
      'password': password,
    };
  }
}

class LoginRequest {
  const LoginRequest({
    required this.identifier,
    required this.password,
  });

  final String identifier;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'password': password,
    };
  }
}

class TwoFactorLoginRequest {
  const TwoFactorLoginRequest({
    required this.preAuthToken,
    required this.otp,
  });

  final String preAuthToken;
  final String otp;

  Map<String, dynamic> toJson() {
    return {
      'preAuthToken': preAuthToken,
      'otp': otp,
    };
  }
}

class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.identifier,
    required this.resetToken,
    required this.newPassword,
  });

  final String identifier;
  final String resetToken;
  final String newPassword;

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'resetToken': resetToken,
      'newPassword': newPassword,
    };
  }
}

class ChangePasswordRequest {
  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  Map<String, dynamic> toJson() {
    return {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
  }
}

class MessageResponse {
  const MessageResponse({
    required this.message,
    this.resetToken,
    this.expiresInMinutes,
  });

  final String message;
  final String? resetToken;
  final int? expiresInMinutes;
}

class LoginResponse {
  const LoginResponse({
    required this.message,
    this.accessToken,
    this.preAuthToken,
    this.requiresTwoFactor = false,
    this.passwordExpired = false,
    this.mustChangePassword = false,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['message']?.toString() ?? 'Operacion completada.',
      accessToken: json['accessToken']?.toString(),
      preAuthToken: json['preAuthToken']?.toString(),
      requiresTwoFactor: json['requiresTwoFactor'] == true,
      passwordExpired: json['passwordExpired'] == true,
      mustChangePassword: json['mustChangePassword'] == true,
    );
  }

  final String message;
  final String? accessToken;
  final String? preAuthToken;
  final bool requiresTwoFactor;
  final bool passwordExpired;
  final bool mustChangePassword;
}

class TwoFactorSetupResponse {
  const TwoFactorSetupResponse({
    required this.message,
    required this.secret,
    required this.otpauthUrl,
  });

  factory TwoFactorSetupResponse.fromJson(Map<String, dynamic> json) {
    return TwoFactorSetupResponse(
      message: json['message']?.toString() ?? 'Configuracion 2FA generada.',
      secret: json['secret']?.toString() ?? '',
      otpauthUrl: json['otpauthUrl']?.toString() ?? '',
    );
  }

  final String message;
  final String secret;
  final String otpauthUrl;
}

class SessionResponse {
  const SessionResponse({
    required this.message,
    required this.usuario,
    required this.nombres,
    required this.apellidos,
    required this.email,
    required this.twoFactorEnabled,
    required this.passwordExpired,
    required this.mustChangePassword,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(
      message: json['message']?.toString() ?? 'Sesion valida.',
      usuario: json['usuario']?.toString() ?? '',
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      twoFactorEnabled: json['twoFactorEnabled'] == true,
      passwordExpired: json['passwordExpired'] == true,
      mustChangePassword: json['mustChangePassword'] == true,
    );
  }

  final String message;
  final String usuario;
  final String nombres;
  final String apellidos;
  final String email;
  final bool twoFactorEnabled;
  final bool passwordExpired;
  final bool mustChangePassword;
}

int _readInt(dynamic value, int fallback) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _readNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}
