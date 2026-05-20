import 'package:flutter/material.dart';

import 'features/auth/auth_page.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/dashboard_page.dart';
import 'features/auth/session_store.dart';

void main() {
  runApp(const OptometriaApp());
}

class OptometriaApp extends StatelessWidget {
  const OptometriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF0F6170);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Optometria Movil',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5FAFA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xFF7B9094)),
          labelStyle: const TextStyle(color: Color(0xFF5E747A)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: seedColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AuthService _authService = AuthService();
  final SessionStore _sessionStore = SessionStore();

  bool _checkingSession = true;
  String? _token;
  SessionResponse? _session;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await _sessionStore.readToken();

    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingSession = false;
        _token = null;
        _session = null;
      });
      return;
    }

    try {
      final session = await _authService.getSession(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingSession = false;
        _token = token;
        _session = session;
      });
    } catch (_) {
      await _sessionStore.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingSession = false;
        _token = null;
        _session = null;
      });
    }
  }

  Future<void> _handleAuthenticated(String token) async {
    setState(() => _checkingSession = true);
    await _sessionStore.saveToken(token);
    try {
      final session = await _authService.getSession(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingSession = false;
        _token = token;
        _session = session;
      });
    } catch (_) {
      await _sessionStore.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingSession = false;
        _token = null;
        _session = null;
      });
    }
  }

  Future<void> _refreshSession() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    final session = await _authService.getSession(token);
    if (!mounted) {
      return;
    }
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    await _sessionStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _token = null;
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const _SessionSplash();
    }

    final token = _token;
    final session = _session;

    if (token != null && session != null) {
      return DashboardPage(
        token: token,
        session: session,
        onLogout: _logout,
        onRefreshSession: _refreshSession,
      );
    }

    return AuthPage(onAuthenticated: _handleAuthenticated);
  }
}

class _SessionSplash extends StatelessWidget {
  const _SessionSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0B2028),
              Color(0xFF143E4D),
              Color(0xFFF0F7F8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 18),
              Text(
                'Validando sesion...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
