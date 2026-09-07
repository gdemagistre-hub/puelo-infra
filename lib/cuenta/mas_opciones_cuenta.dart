import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import '../loginScreen.dart';
import '../theme/app_colors.dart';
import '../user_session.dart';
import 'cuenta_service.dart';

class MasOpcionesCuentaWidget extends StatefulWidget {
  final bool modoPrestador;
  final bool abrirEliminar;

  const MasOpcionesCuentaWidget({
    super.key,
    this.modoPrestador = false,
    this.abrirEliminar = false,
  });

  @override
  State<MasOpcionesCuentaWidget> createState() =>
      _MasOpcionesCuentaWidgetState();
}

class _MasOpcionesCuentaWidgetState extends State<MasOpcionesCuentaWidget> {
  Color get _primary =>
      AppColors.primaryFor(modoPrestador: widget.modoPrestador);

  @override
  void initState() {
    super.initState();
    if (widget.abrirEliminar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confirmarEliminar();
      });
    }
  }

  Future<void> _abrirMensaje() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MensajeDesarrolladorWidget(
          modoPrestador: widget.modoPrestador,
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar() async {
    if (UserSession().isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Las cuentas admin no se eliminan desde la app.',
          ),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta acción elimina tu cuenta y no se puede restaurar. '
          'El perfil deja de estar activo ahora. '
          'Los archivos asociados se borran dentro de 24 h.\n\n'
          '¿Deseás continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await CuentaService.instance.solicitarEliminacionCuenta();
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreenWidget()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.text,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Más opciones',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _tile(
            icon: Icons.mail_outline_rounded,
            title: 'Mensaje al desarrollador',
            subtitle: 'Consultas o para reportar un contenido.',
            onTap: _abrirMensaje,
          ),
          const SizedBox(height: 12),
          _tile(
            icon: Icons.person_off_outlined,
            title: 'Eliminar cuenta',
            subtitle: 'Baja definitiva. No se puede deshacer.',
            danger: true,
            onTap: _confirmarEliminar,
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? Colors.red.shade700 : _primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: danger ? Colors.red.shade100 : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: danger ? Colors.red.shade700 : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class MensajeDesarrolladorWidget extends StatefulWidget {
  final bool modoPrestador;
  const MensajeDesarrolladorWidget({super.key, this.modoPrestador = false});

  @override
  State<MensajeDesarrolladorWidget> createState() =>
      _MensajeDesarrolladorWidgetState();
}

class _MensajeDesarrolladorWidgetState
    extends State<MensajeDesarrolladorWidget> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  Color get _primary =>
      AppColors.primaryFor(modoPrestador: widget.modoPrestador);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribí un mensaje.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await CuentaService.instance.enviarMensajeDesarrollador(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensaje enviado.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final n = _ctrl.text.characters.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.text,
          onPressed: _sending ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Mensaje al desarrollador',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Escribí tu consulta o reportá un contenido. Máximo 800 caracteres.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLength: CuentaService.maxMensaje,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(CuentaService.maxMensaje),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tu mensaje',
                  filled: true,
                  fillColor: Colors.white,
                  counterText: '$n / ${CuentaService.maxMensaje}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _primary, width: 1.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _sending ? null : _enviar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enviar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
