import 'package:flutter/material.dart';

import 'cuenta/mas_opciones_cuenta.dart';
import 'legales/documento_legal_screen.dart';
import 'legales/textos_legales.dart';
import 'theme/app_colors.dart';

class AcercaDeWidget extends StatelessWidget {
  final bool modoPrestador;

  const AcercaDeWidget({super.key, this.modoPrestador = false});

  static const String versionLabel = 'Versión 1.0.3 (14)';
  static const String copyright = 'Copyright 2026 — Puelo.app';

  Color get _primary =>
      AppColors.primaryFor(modoPrestador: modoPrestador);

  void _legal(BuildContext context, TipoDocumentoLegal tipo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentoLegalScreen(
          tipo: tipo,
          modoPrestador: modoPrestador,
        ),
      ),
    );
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
          'Acerca de',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            versionLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            copyright,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          _card([
            _row(
              context,
              Icons.description_outlined,
              'Términos y Condiciones',
              () => _legal(context, TipoDocumentoLegal.terminos),
            ),
            _row(
              context,
              Icons.privacy_tip_outlined,
              'Privacidad e identidad',
              () => _legal(context, TipoDocumentoLegal.privacidad),
            ),
            _row(
              context,
              Icons.handshake_outlined,
              'Buenas prácticas',
              () => _legal(context, TipoDocumentoLegal.buenasPracticas),
            ),
            _row(
              context,
              Icons.child_care_outlined,
              'Protección infantil',
              () => _legal(context, TipoDocumentoLegal.csae),
            ),
          ]),
          const SizedBox(height: 16),
          _card([
            _row(
              context,
              Icons.mail_outline_rounded,
              'Contacto',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MensajeDesarrolladorWidget(
                      modoPrestador: modoPrestador,
                    ),
                  ),
                );
              },
            ),
            _row(
              context,
              Icons.person_off_outlined,
              'Cancelar cuenta',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MasOpcionesCuentaWidget(
                      modoPrestador: modoPrestador,
                      abrirEliminar: true,
                    ),
                  ),
                );
              },
              danger: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _card(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) {
        children.add(Divider(height: 1, indent: 56, color: Colors.grey.shade200));
      }
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? Colors.red.shade700 : _primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: danger ? Colors.red.shade700 : AppColors.text,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
