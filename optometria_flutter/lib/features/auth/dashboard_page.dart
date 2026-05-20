import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import 'auth_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.token,
    required this.session,
    required this.onLogout,
    required this.onRefreshSession,
  });

  final String token;
  final SessionResponse session;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefreshSession;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmTwoFactorController = TextEditingController();
  final _changePasswordFormKey = GlobalKey<FormState>();

  bool _busy = false;
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  String? _twoFactorSecret;
  String? _otpAuthUrl;
  String _statusMessage = 'Sesion restaurada correctamente.';

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmTwoFactorController.dispose();
    super.dispose();
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

  Future<void> _handleChangePassword() async {
    if (!_changePasswordFormKey.currentState!.validate()) {
      return;
    }

    await _runBusy(() async {
      final response = await _authService.changePassword(
        ChangePasswordRequest(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        ),
        widget.token,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      await widget.onRefreshSession();

      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = response.message);
    });
  }

  Future<void> _handleSetupTwoFactor() async {
    await _runBusy(() async {
      final response = await _authService.setupTwoFactor(widget.token);
      if (!mounted) {
        return;
      }
      setState(() {
        _twoFactorSecret = response.secret;
        _otpAuthUrl = response.otpauthUrl;
        _statusMessage = response.message;
      });
    });
  }

  Future<void> _handleConfirmTwoFactor() async {
    if (_confirmTwoFactorController.text.trim().isEmpty) {
      setState(() => _statusMessage = 'Ingresa el OTP para confirmar el 2FA.');
      return;
    }

    await _runBusy(() async {
      final response = await _authService.confirmTwoFactor(
        _confirmTwoFactorController.text.trim(),
        widget.token,
      );

      await widget.onRefreshSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _confirmTwoFactorController.clear();
        _statusMessage = response.message;
      });
    });
  }

  Future<void> _handleLogout() async {
    await _runBusy(() async {
      await widget.onLogout();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final fullName = [session.nombres, session.apellidos]
        .where((value) => value.trim().isNotEmpty)
        .join(' ');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF5FAFA),
              Color(0xFFEAF2F7),
              Color(0xFFF8FBFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D2430), Color(0xFF135064)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 28,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 760;
                          final info = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x19FFFFFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Dashboard autenticado',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                fullName.isEmpty ? session.usuario : fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                session.email.isEmpty
                                    ? 'Usuario: ${session.usuario}'
                                    : '${session.usuario} - ${session.email}',
                                style: const TextStyle(
                                  color: Color(0xCCE4F3F5),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _SessionBadge(
                                    label: session.passwordExpired
                                        ? 'Contrasena expirada'
                                        : 'Contrasena vigente',
                                  ),
                                  _SessionBadge(
                                    label: session.mustChangePassword
                                        ? 'Cambio obligatorio'
                                        : 'Cambio opcional',
                                  ),
                                  _SessionBadge(
                                    label: session.twoFactorEnabled
                                        ? '2FA activo'
                                        : '2FA pendiente',
                                  ),
                                ],
                              ),
                            ],
                          );

                          final actions = Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        widget.onRefreshSession();
                                      },
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Actualizar sesion'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white38),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        _handleLogout();
                                      },
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Cerrar sesion'),
                              ),
                            ],
                          );

                          if (stacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                info,
                                const SizedBox(height: 18),
                                actions,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: info),
                              const SizedBox(width: 16),
                              actions,
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _DashboardStat(
                          label: 'Sesion',
                          value: 'Activa',
                          helper:
                              'El login se omite cuando el token guardado sigue vigente.',
                        ),
                        _DashboardStat(
                          label: 'Autenticacion',
                          value: session.twoFactorEnabled ? '2FA activa' : '1 factor',
                          helper: 'Puedes configurar o confirmar el doble factor abajo.',
                        ),
                        _DashboardStat(
                          label: 'Seguridad',
                          value: session.mustChangePassword ? 'Atencion' : 'Estable',
                          helper: session.passwordExpired
                              ? 'La contrasena ya expiro.'
                              : 'La contrasena sigue vigente.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 900;
                        if (stacked) {
                          return Column(
                            children: [
                              _buildChangePasswordCard(session),
                              const SizedBox(height: 16),
                              _buildTwoFactorCard(session),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildChangePasswordCard(session)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTwoFactorCard(session)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xFFDCE7EA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF0F6170),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMessage,
                              style: const TextStyle(
                                color: Color(0xFF24424A),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 18),
                      const LinearProgressIndicator(minHeight: 4),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChangePasswordCard(SessionResponse session) {
    return _SectionCard(
      title: 'Cambio de contrasena',
      subtitle: session.mustChangePassword
          ? 'Este usuario debe actualizar la contrasena.'
          : 'Puedes actualizar la contrasena desde aqui.',
      accent: const Color(0xFF0F6170),
      child: Form(
        key: _changePasswordFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Contrasena actual',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _currentPasswordVisible = !_currentPasswordVisible;
                    });
                  },
                  icon: Icon(
                    _currentPasswordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              obscureText: !_currentPasswordVisible,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'Nueva contrasena',
                prefixIcon: const Icon(Icons.password_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _newPasswordVisible = !_newPasswordVisible;
                    });
                  },
                  icon: Icon(
                    _newPasswordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              obscureText: !_newPasswordVisible,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _handleChangePassword,
                child: const Text('Actualizar contrasena'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwoFactorCard(SessionResponse session) {
    return _SectionCard(
      title: 'Doble factor',
      subtitle: session.twoFactorEnabled
          ? 'El 2FA ya aparece como activo en la sesion.'
          : 'Genera el secreto y confirma el OTP para activar el 2FA.',
      accent: const Color(0xFF6C4CCF),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _handleSetupTwoFactor,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Generar secreto 2FA'),
            ),
          ),
          if ((_twoFactorSecret ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    'Secret: $_twoFactorSecret',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'OTPAuth: ${_otpAuthUrl ?? ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5D5D77),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmTwoFactorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'OTP de confirmacion',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _handleConfirmTwoFactor,
                child: const Text('Confirmar activacion 2FA'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFDDE7E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17353D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF617A80),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SessionBadge extends StatelessWidget {
  const _SessionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x19FFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  const _DashboardStat({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDCE7EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B8288),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF17353D),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              helper,
              style: const TextStyle(
                color: Color(0xFF5E767C),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
