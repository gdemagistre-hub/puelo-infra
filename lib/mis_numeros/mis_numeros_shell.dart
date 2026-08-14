import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../user_session.dart';
import 'crypto/vault_session.dart';
import 'data/metas_store.dart';
import 'data/movimientos_store.dart';
import 'data/vencimientos_store.dart';
import 'ui/mis_numeros_content.dart';

/// Shell Mis números — DB única lifewalletpuelo.
class MisNumerosShell extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const MisNumerosShell({super.key, this.onBackToHome});
  @override
  State<MisNumerosShell> createState() => _MisNumerosShellState();
}

enum _Phase {
  loading,
  needsRealAuth,
  pinSetup,
  pinUnlock,
  pinReset,
  ready,
}

class _MisNumerosShellState extends State<MisNumerosShell> {
  _Phase _phase = _Phase.loading;
  final _store = MovimientosStore();
  final _metasStore = MetasStore();
  final _vencimientosStore = VencimientosStore();
  bool _storeLoaded = false;

  @override
  void initState() {
    super.initState();
    VaultSession.instance.addListener(_onVault);
    _bootstrap();
  }

  @override
  void dispose() {
    VaultSession.instance.removeListener(_onVault);
    super.dispose();
  }

  void _onVault() {
    if (!mounted) return;
    final v = VaultSession.instance;
    if ((_phase == _Phase.pinSetup ||
            _phase == _Phase.pinUnlock ||
            _phase == _Phase.pinReset) &&
        v.isUnlocked) {
      _enterReady();
    }
  }

  Future<void> _bootstrap() async {
    setState(() => _phase = _Phase.loading);
    final session = UserSession();
    final user = FirebaseAuth.instance.currentUser;
    if (!session.isLoggedIn || session.isDevImpersonation || user == null) {
      setState(() => _phase = _Phase.needsRealAuth);
      return;
    }
    await VaultSession.instance.bindUser(user.uid);
    if (!VaultSession.instance.hasVault) {
      setState(() => _phase = _Phase.pinSetup);
      return;
    }
    if (!VaultSession.instance.isUnlocked) {
      setState(() => _phase = _Phase.pinUnlock);
      return;
    }
    await _enterReady();
  }

  Future<void> _enterReady() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = VaultSession.instance.uid ?? user?.uid;
    if (!_storeLoaded) {
      await Future.wait([
        _store.loadForUser(uid),
        _metasStore.loadForUser(uid),
        _vencimientosStore.loadForUser(uid),
      ]);
      if (user != null) {
        await _store.ensureUserProfile(
          email: user.email,
          displayName: user.displayName ?? UserSession().nombreCompleto,
        );
      }
      _storeLoaded = true;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.ready);
  }

  void _lock() {
    VaultSession.instance.lock();
    setState(() => _phase = _Phase.pinUnlock);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const ColoredBox(
          color: Color(0xFFF1F5F9),
          child: Center(child: CircularProgressIndicator()),
        );
      case _Phase.needsRealAuth:
        return _InfoCard(
          icon: Icons.login_rounded,
          title: 'Entrá con Google',
          body:
              'Mis números necesita sesión con Google (no el dropdown de prueba).',
          primaryLabel: 'Volver al inicio',
          onPrimary: widget.onBackToHome,
        );
      case _Phase.pinSetup:
        return _PinSetupEmbedded(
          onDone: () => _enterReady(),
          onBack: widget.onBackToHome,
        );
      case _Phase.pinUnlock:
        return _PinUnlockEmbedded(
          onUnlocked: () => _enterReady(),
          onForgotPin: () => setState(() => _phase = _Phase.pinReset),
          onBack: widget.onBackToHome,
        );
      case _Phase.pinReset:
        return _PinResetEmbedded(
          onDone: () => _enterReady(),
          onBack: () => setState(() => _phase = _Phase.pinUnlock),
        );
      case _Phase.ready:
        return MisNumerosContent(
          store: _store,
          metasStore: _metasStore,
          vencimientosStore: _vencimientosStore,
          onLock: _lock,
        );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.cliente.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cliente.withOpacity(0.28),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, size: 42, color: AppColors.cliente),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 28),
                if (primaryLabel != null && onPrimary != null)
                  FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.cliente,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(primaryLabel!),
                  ),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: onSecondary, child: Text(secondaryLabel!)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinSetupEmbedded extends StatefulWidget {
  const _PinSetupEmbedded({required this.onDone, this.onBack});
  final VoidCallback onDone;
  final VoidCallback? onBack;
  @override
  State<_PinSetupEmbedded> createState() => _PinSetupEmbeddedState();
}

class _PinSetupEmbeddedState extends State<_PinSetupEmbedded> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final a = _pin1.text.trim();
    final b = _pin2.text.trim();
    if (a.length != 6 || b.length != 6) {
      setState(() => _error = 'El PIN debe tener 6 dígitos');
      return;
    }
    if (a != b) {
      setState(() => _error = 'Los PIN no coinciden');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await VaultSession.instance.setupPin(a);
      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      setState(() => _error = 'No se pudo crear la bóveda: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Icon(Icons.lock_rounded, size: 48, color: Color(0xFF28B5CD)),
            const SizedBox(height: 16),
            const Text(
              'Clave financiera',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tu PIN bloquea Mis números en el celular.\n'
              'Si lo olvidás, entrás de nuevo con Google y elegís uno nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _pin1,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Elegí 6 dígitos',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin2,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Repetí el PIN',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF28B5CD),
                minimumSize: const Size.fromHeight(48),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Crear PIN'),
            ),
            if (widget.onBack != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onBack,
                child: const Text('Volver al inicio'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinUnlockEmbedded extends StatefulWidget {
  const _PinUnlockEmbedded({
    required this.onUnlocked,
    this.onForgotPin,
    this.onBack,
  });
  final VoidCallback onUnlocked;
  final VoidCallback? onForgotPin;
  final VoidCallback? onBack;
  @override
  State<_PinUnlockEmbedded> createState() => _PinUnlockEmbeddedState();
}

class _PinUnlockEmbeddedState extends State<_PinUnlockEmbedded> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;
  int _fails = 0;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    if (_fails >= 8) {
      setState(() => _error = 'Demasiados intentos. Volvé más tarde.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await VaultSession.instance.unlock(_pin.text.trim());
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      _fails++;
      setState(() {
        _error = VaultSession.instance.lastError ?? 'PIN incorrecto';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(children: [
            const Icon(Icons.lock_open_rounded,
                size: 48, color: Color(0xFF28B5CD)),
            const SizedBox(height: 16),
            const Text(
              'Desbloquear mis números',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu PIN bloquea Mis números en el celular.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _pin,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _abrir(),
              decoration: const InputDecoration(
                labelText: 'PIN de 6 dígitos',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _abrir,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF28B5CD),
                minimumSize: const Size.fromHeight(48),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Entrar'),
            ),
            if (widget.onForgotPin != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onForgotPin,
                child: const Text('Olvidé el PIN'),
              ),
            ],
            const Spacer(),
            if (widget.onBack != null)
              TextButton(
                onPressed: widget.onBack,
                child: const Text('Volver al inicio'),
              ),
          ]),
        ),
      ),
    );
  }
}

class _PinResetEmbedded extends StatefulWidget {
  const _PinResetEmbedded({required this.onDone, this.onBack});
  final VoidCallback onDone;
  final VoidCallback? onBack;
  @override
  State<_PinResetEmbedded> createState() => _PinResetEmbeddedState();
}

class _PinResetEmbeddedState extends State<_PinResetEmbedded> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final a = _pin1.text.trim();
    final b = _pin2.text.trim();
    if (a.length != 6 || b.length != 6) {
      setState(() => _error = 'El PIN debe tener 6 dígitos');
      return;
    }
    if (a != b) {
      setState(() => _error = 'Los PIN no coinciden');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await VaultSession.instance.resetPinWithRecovery(a);
      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      setState(() {
        _error = 'No se pudo recuperar. Detalle: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Icon(Icons.pin_rounded, size: 48, color: Color(0xFF28B5CD)),
            const SizedBox(height: 16),
            const Text(
              'Nuevo PIN',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Estás con Google. Elegí un PIN nuevo.\n'
              'Tu historial se mantiene (bóvedas con recuperación).',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _pin1,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Nuevo PIN (6 dígitos)',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin2,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Repetí el PIN',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF28B5CD),
                minimumSize: const Size.fromHeight(48),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar nuevo PIN'),
            ),
            if (widget.onBack != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onBack,
                child: const Text('Volver'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
