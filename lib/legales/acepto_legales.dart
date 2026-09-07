import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../Homepage.dart';
import '../elige_camino.dart';
import '../elige_pais.dart';
import '../theme/app_colors.dart';
import '../user_session.dart';
import 'documento_legal_screen.dart';
import 'textos_legales.dart';

/// Gate post-login: Google/Apple no pasan por Crear cuenta.
/// Se pide una vez y se guarda en usuarios/{uid}.
class AceptoLegalesWidget extends StatefulWidget {
  const AceptoLegalesWidget({super.key});

  static const String routeName = 'AceptoLegales';
  static const String routePath = '/acepto-legales';

  static bool necesitaAceptar() {
    final data = UserSession().datosCompletos;
    if (data == null) return false;
    if (data['legales_aceptados'] == true) return false;
    if (data['legales_aceptados_at'] != null) return false;
    return true;
  }

  static Future<void> persistirAceptacion({
    String? countryCode,
    String? uid,
  }) async {
    uid = (uid ?? UserSession().uid) ?? '';
    final pack = TextosLegales.packId(countryCode);
    final patch = <String, dynamic>{
      'legales_aceptados': true,
      'legales_aceptados_at': FieldValue.serverTimestamp(),
      'legales_pack': pack,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (uid.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set(patch, SetOptions(merge: true));
    }
    final data = Map<String, dynamic>.from(UserSession().datosCompletos ?? {});
    data['legales_aceptados'] = true;
    data['legales_aceptados_at'] = DateTime.now().toUtc().toIso8601String();
    data['legales_pack'] = pack;
    UserSession().datosCompletos = data;
  }

  @override
  State<AceptoLegalesWidget> createState() => _AceptoLegalesWidgetState();
}

class _AceptoLegalesWidgetState extends State<AceptoLegalesWidget> {
  static const Color _accent = AppColors.cliente;
  bool _acepto = false;
  bool _saving = false;

  void _abrir(TipoDocumentoLegal tipo) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentoLegalScreen(tipo: tipo)),
    );
  }

  Future<void> _continuar() async {
    if (_saving) return;
    if (!_acepto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para seguir tenés que aceptar los términos, la privacidad, '
            'las buenas prácticas y la política de protección infantil.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await AceptoLegalesWidget.persistirAceptacion();
    } catch (e) {
      debugPrint('AceptoLegales save: $e');
    }
    if (!mounted) return;
    if (EligePaisWidget.necesitaElegir()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EligePaisWidget()),
      );
      return;
    }
    if (EligeCaminoWidget.necesitaElegir()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EligeCaminoWidget()),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePageWidget(
          initialModoPrestador: UserSession().preferredHomeModoPrestador,
        ),
      ),
    );
  }

  Widget _link(String label, TipoDocumentoLegal tipo) {
    return GestureDetector(
      onTap: () => _abrir(tipo),
      child: Text(
        label,
        style: const TextStyle(
          color: _accent,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Antes de entrar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Leé y aceptá los documentos de PUELO. Es el mismo paso que en Crear cuenta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acepto,
                      activeColor: _accent,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _acepto = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              TextosLegales.checkboxAcepto,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              children: [
                                _link('Términos', TipoDocumentoLegal.terminos),
                                _link(
                                  'Privacidad',
                                  TipoDocumentoLegal.privacidad,
                                ),
                                _link(
                                  'Buenas prácticas',
                                  TipoDocumentoLegal.buenasPracticas,
                                ),
                                _link(
                                  'Protección infantil',
                                  TipoDocumentoLegal.csae,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              TextosLegales.checkboxMicro,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _continuar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _saving ? 'Guardando…' : 'Continuar',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
