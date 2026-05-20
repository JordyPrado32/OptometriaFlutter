import 'package:flutter/material.dart';

import '../../core/api/api_config.dart';
import '../../core/api/api_exception.dart';
import 'auth_service.dart';

enum AuthTab { login, register, recovery }

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.onAuthenticated,
  });

  final Future<void> Function(String token) onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final AuthService _authService = AuthService();

  PasswordPolicy? _policy;
  HealthStatus? _health;
  String? _preAuthToken;
  String _statusMessage = 'Preparamos la conexion con el backend.';
  bool _busy = false;
  bool _loginPasswordVisible = false;
  bool _registerPasswordVisible = false;

  final _loginIdentifierController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  final _registerNamesController = TextEditingController();
  final _registerLastNamesController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerUserController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  final _recoveryIdentifierController = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _recoveryFormKey = GlobalKey<FormState>();

  AuthTab _currentTab = AuthTab.login;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _otpController.dispose();
    _registerNamesController.dispose();
    _registerLastNamesController.dispose();
    _registerEmailController.dispose();
    _registerUserController.dispose();
    _registerPhoneController.dispose();
    _registerPasswordController.dispose();
    _recoveryIdentifierController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _runBusy(() async {
      final health = await _authService.checkHealth();
      final policy = await _authService.getPasswordPolicy();
      if (!mounted) {
        return;
      }
      setState(() {
        _health = health;
        _policy = policy;
        _statusMessage = health.ok
            ? 'Backend listo. Puedes iniciar sesion o registrar usuarios.'
            : 'El backend respondio, pero no confirmo la base de datos.';
      });
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = error.toString());
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    await _runBusy(() async {
      final response = await _authService.login(
        LoginRequest(
          identifier: _loginIdentifierController.text.trim(),
          password: _loginPasswordController.text,
        ),
      );

      if (!mounted) {
        return;
      }

      if (response.requiresTwoFactor && (response.preAuthToken ?? '').isNotEmpty) {
        setState(() {
          _preAuthToken = response.preAuthToken;
          _statusMessage = response.message;
        });
        return;
      }

      final token = response.accessToken;
      if (token == null || token.isEmpty) {
        setState(() => _statusMessage = 'El backend no devolvio un token valido.');
        return;
      }

      setState(() => _statusMessage = response.message);
      await widget.onAuthenticated(token);
    });
  }

  Future<void> _handleVerifyTwoFactor() async {
    if ((_preAuthToken ?? '').isEmpty || _otpController.text.trim().isEmpty) {
      setState(() {
        _statusMessage = 'Ingresa el codigo OTP para completar el acceso.';
      });
      return;
    }

    await _runBusy(() async {
      final response = await _authService.verifyTwoFactor(
        TwoFactorLoginRequest(
          preAuthToken: _preAuthToken!,
          otp: _otpController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }

      final token = response.accessToken;
      if (token == null || token.isEmpty) {
        setState(() => _statusMessage = 'No se recibio token luego del OTP.');
        return;
      }

      setState(() {
        _preAuthToken = null;
        _otpController.clear();
        _statusMessage = response.message;
      });
      await widget.onAuthenticated(token);
    });
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) {
      return;
    }

    await _runBusy(() async {
      final response = await _authService.register(
        RegisterRequest(
          nombres: _registerNamesController.text.trim(),
          apellidos: _registerLastNamesController.text.trim(),
          email: _registerEmailController.text.trim(),
          usuario: _registerUserController.text.trim(),
          telefono: _registerPhoneController.text.trim(),
          password: _registerPasswordController.text,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentTab = AuthTab.login;
        _loginIdentifierController.text = _registerUserController.text.trim();
        _statusMessage = response.message;
      });
    });
  }

  Future<void> _handleRecovery() async {
    if (!_recoveryFormKey.currentState!.validate()) {
      return;
    }

    await _runBusy(() async {
      final response = await _authService.requestPasswordReset(
        _recoveryIdentifierController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() => _statusMessage = response.message);
    });
  }

  void _cancelTwoFactorFlow() {
    setState(() {
      _preAuthToken = null;
      _otpController.clear();
      _statusMessage = 'Flujo 2FA cancelado. Puedes intentar de nuevo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF081C24),
              Color(0xFF103645),
              Color(0xFFEDF6F6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.42, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(child: _buildHeroPanel()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildAccessPanel()),
                        ],
                      )
                    : ListView(
                        children: [
                          _buildHeroPanel(),
                          const SizedBox(height: 24),
                          _buildAccessPanel(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPanel() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          colors: [Color(0xCC0D2430), Color(0xCC144354)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Optometria Movil - acceso seguro',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Ingresa a tu operacion clinica con una interfaz mas clara y una sesion que se recuerda.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Hicimos el acceso mas visual, agregamos visibilidad de contrasena y dejamos lista la validacion para enviar al usuario directo al dashboard cuando ya tenga sesion vigente.',
            style: TextStyle(
              color: Color(0xCDE4F3F5),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _GlassMetric(
                label: 'Backend',
                value: _health?.ok == true ? 'Disponible' : 'Pendiente',
              ),
              _GlassMetric(
                label: 'Base de datos',
                value: _health?.databaseStatus ?? 'Sin validar',
              ),
              _GlassMetric(
                label: 'URL base',
                value: ApiConfig.baseUrl,
                wide: true,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0x12FFFFFF),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Politica del backend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ..._policyItems(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF3FBFB),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              _statusMessage,
              style: const TextStyle(
                color: Color(0xFF17353D),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _policyItems() {
    final policy = _policy;
    if (policy == null) {
      return const [
        Text(
          'Cargando politica...',
          style: TextStyle(color: Color(0xCCFFFFFF)),
        ),
      ];
    }

    final items = [
      'Minimo ${policy.minLength} caracteres',
      'Mayuscula, minuscula, numero y caracter especial',
      'Sin datos personales evidentes',
      'Expiracion cada ${policy.expiresInDays} dias',
      'Bloqueo tras ${policy.maxFailedAttempts} intentos por ${policy.lockoutMinutes} minutos',
    ];

    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF8CF3D0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xD7F2F7F7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _buildAccessPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFB),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFD8E8E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Centro de acceso',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF123039),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _bootstrap,
                  icon: const Icon(Icons.refresh_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE5F2F1),
                    foregroundColor: const Color(0xFF123039),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando la sesion ya existe y sigue valida, el usuario entra directo al dashboard.',
              style: TextStyle(
                color: Color(0xFF557278),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (_preAuthToken != null) _buildTwoFactorCard(),
            if (_preAuthToken == null) ...[
              _buildTabSelector(),
              const SizedBox(height: 22),
              _buildCurrentForm(),
            ],
            if (_busy) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(minHeight: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2F2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: AuthTab.values.map((tab) {
          final selected = _currentTab == tab;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF123039) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _busy
                    ? null
                    : () {
                        setState(() => _currentTab = tab);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _tabLabel(tab),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF4B676E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentForm() {
    switch (_currentTab) {
      case AuthTab.login:
        return _buildLoginForm();
      case AuthTab.register:
        return _buildRegisterForm();
      case AuthTab.recovery:
        return _buildRecoveryForm();
    }
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _loginIdentifierController,
            decoration: const InputDecoration(
              labelText: 'Usuario o email',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _loginPasswordController,
            decoration: InputDecoration(
              labelText: 'Contrasena',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _loginPasswordVisible = !_loginPasswordVisible);
                },
                icon: Icon(
                  _loginPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
            obscureText: !_loginPasswordVisible,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _handleLogin,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Entrar al dashboard'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 540;
          final identityFields = compact
              ? Column(
                  children: [
                    TextFormField(
                      controller: _registerNamesController,
                      decoration: const InputDecoration(labelText: 'Nombres'),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _registerLastNamesController,
                      decoration: const InputDecoration(labelText: 'Apellidos'),
                      validator: _requiredValidator,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _registerNamesController,
                        decoration: const InputDecoration(labelText: 'Nombres'),
                        validator: _requiredValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _registerLastNamesController,
                        decoration: const InputDecoration(labelText: 'Apellidos'),
                        validator: _requiredValidator,
                      ),
                    ),
                  ],
                );

          return Column(
            children: [
              identityFields,
              const SizedBox(height: 14),
              TextFormField(
                controller: _registerUserController,
                decoration: const InputDecoration(labelText: 'Usuario'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _registerEmailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _registerPhoneController,
                decoration: const InputDecoration(labelText: 'Telefono'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _registerPasswordController,
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _registerPasswordVisible = !_registerPasswordVisible;
                      });
                    },
                    icon: Icon(
                      _registerPasswordVisible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                obscureText: !_registerPasswordVisible,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _handleRegister,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Crear usuario'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecoveryForm() {
    return Form(
      key: _recoveryFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _recoveryIdentifierController,
            decoration: const InputDecoration(
              labelText: 'Usuario o email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _handleRecovery,
              icon: const Icon(Icons.mark_email_read_rounded),
              label: const Text('Enviar recuperacion'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoFactorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF0D8A9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verificacion 2FA requerida',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6E4A00),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ingresa el codigo generado por tu app autenticadora para completar el acceso.',
            style: TextStyle(
              color: Color(0xFF7F611C),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Codigo OTP',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 430;
              if (vertical) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _handleVerifyTwoFactor,
                        child: const Text('Validar OTP'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _cancelTwoFactorFlow,
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _handleVerifyTwoFactor,
                      child: const Text('Validar OTP'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _cancelTwoFactorFlow,
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _tabLabel(AuthTab tab) {
    switch (tab) {
      case AuthTab.login:
        return 'Login';
      case AuthTab.register:
        return 'Registro';
      case AuthTab.recovery:
        return 'Recuperar';
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }
    return null;
  }
}

class _GlassMetric extends StatelessWidget {
  const _GlassMetric({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 260 : 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xB3EAF8F8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
