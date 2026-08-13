import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../user_session.dart';
import 'crypto/vault_session.dart';
import 'data/movimientos_store.dart';
import 'finanzas_bridge.dart';
import 'ui/mis_numeros_content.dart';

/// Shell Mis numeros embebido en Homepage.
/// Flujo: Auth real → bridge Finanzas → PIN → movimientos cifrados.
class MisNumerosShell extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const MisNumerosShell({super.key, this.onBackToHome});
  @override
  State<MisNumerosShell> createState() => _MisNumerosShellState();
}

enum _Phase { loading, needsRealAuth, bridgeError, pinSetup, pinUnlock, ready }

class _MisNumerosShellState extends State<MisNumerosShell> {
  _Phase _phase = _Phase.loading;
  String? _error;
  final _store = MovimientosStore();
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
    if ((_phase == _Phase.pinSetup || _phase == _Phase.pinUnlock) && v.isUnlocked) {
      _enterReady();
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    final session = UserSession();
    if (!session.isLoggedIn ||
        session.isDevImpersonation ||
        FirebaseAuth.instance.currentUser == null) {
      setState(() => _phase = _Phase.needsRealAuth);
      return;
    }
    try {
      await FinanzasBridge.ensureInit();
      final finUser = await FinanzasBridge.linkSession();
      await VaultSession.instance.bindUser(finUser.uid);
      if (!VaultSession.instance.hasVault) {
        setState(() => _phase = _Phase.pinSetup);
        return;
      }
      if (!VaultSession.instance.isUnlocked) {
        setState(() => _phase = _Phase.pinUnlock);
        return;
      }
      await _enterReady();
    } catch (e) {
      setState(() {
        _phase = _Phase.bridgeError;
        _error = e.toString();
      });
    }
  }

  Future<void> _enterReady() async {
    final uid = VaultSession.instance.uid ?? FinanzasBridge.finanzasAuth.currentUser?.uid;
    if (!_storeLoaded) {
      await _store.loadForUser(uid);
      final user = FinanzasBridge.finanzasAuth.currentUser;
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
        return const ColoredBox(color: Color(0xFFF1F5F9), child: Center(child: CircularProgressIndicator()));
      case _Phase.needsRealAuth:
        return _InfoCard(
          icon: Icons.login_rounded,
          title: 'Entra con Google',
          body: 'Mis numeros usa cifrado real y necesita sesion Firebase Auth. '
              'El dropdown de prueba no genera token: cierra sesion y volve a entrar con Google.',
          primaryLabel: 'Volver al inicio',
          onPrimary: widget.onBackToHome,
        );
      case _Phase.bridgeError:
        return _InfoCard(
          icon: Icons.cloud_off_rounded,
          title: 'No se pudo vincular Finanzas',
          body: 'Login PROX OK, pero falta el bridge (Cloud Function exchangeWalletToken).\n\n${_error ?? ''}',
          primaryLabel: 'Reintentar',
          onPrimary: _bootstrap,
          secondaryLabel: 'Volver al inicio',
          onSecondary: widget.onBackToHome,
        );
      case _Phase.pinSetup:
        return _PinSetupEmbedded(onDone: () => _enterReady(), onBack: widget.onBackToHome);
      case _Phase.pinUnlock:
        return _PinUnlockEmbedded(onUnlocked: () => _enterReady(), onBack: widget.onBackToHome);
      case _Phase.ready:
        return MisNumerosContent(store: _store, onLock: _lock);
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
                    border: Border.all(color: AppColors.cliente.withOpacity(0.28), width: 1.5),
                  ),
                  child: Icon(icon, size: 42, color: AppColors.cliente),
                ),
                const SizedBox(height: 24),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 12),
                Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textMuted)),
                const SizedBox(height: 28),
                if (primaryLabel != null && onPrimary != null)
                  FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.cliente, minimumSize: const Size.fromHeight(48)),
                    child: Text(primaryLabel!),
                  ),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 12),
                  TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
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
      setState(() => _error = 'El PIN debe tener 6 digitos');
      return;
    }
    if (a != b) {
      setState(() => _error = 'Los PIN no coinciden');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await VaultSession.instance.setupPin(a);
      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      setState(() => _error = 'No se pudo crear la boveda: $e');
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
            const Text('Clave financiera', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
              'Tus numeros se guardan cifrados en Finanzas. Esta clave de 6 digitos solo la sabes vos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 8),
            const Text(
              'Si la olvidas, no se pueden recuperar los montos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _pin1,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Elegi 6 digitos', counterText: '', filled: true, fillColor: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin2,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Repeti el PIN', counterText: '', filled: true, fillColor: Colors.white),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _guardar,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF28B5CD), minimumSize: const Size.fromHeight(48)),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Crear boveda cifrada'),
            ),
            if (widget.onBack != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: widget.onBack, child: const Text('Volver al inicio')),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinUnlockEmbedded extends StatefulWidget {
  const _PinUnlockEmbedded({required this.onUnlocked, this.onBack});
  final VoidCallback onUnlocked;
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
      setState(() => _error = 'Demasiados intentos. Volve mas tarde.');
      return;
    }
    setState(() { _busy = true; _error = null; });
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
            const Icon(Icons.lock_open_rounded, size: 48, color: Color(0xFF28B5CD)),
            const SizedBox(height: 16),
            const Text('Desbloquear mis numeros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Datos financieros cifrados. Solo vos tenes el PIN.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 32),
            TextField(
              controller: _pin,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _abrir(),
              decoration: const InputDecoration(labelText: 'PIN de 6 digitos', counterText: '', filled: true, fillColor: Colors.white),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _abrir,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF28B5CD), minimumSize: const Size.fromHeight(48)),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Entrar a mis numeros'),
            ),
            const Spacer(),
            if (widget.onBack != null) TextButton(onPressed: widget.onBack, child: const Text('Volver al inicio')),
          ]),
        ),
      ),
    );
  }
}
