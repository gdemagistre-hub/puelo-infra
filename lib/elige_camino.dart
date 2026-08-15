import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Homepage.dart';
import 'elige_oficio.dart';
import 'user_session.dart';

/// Primera decisión post-login: ¿busca o ofrece servicios?
/// Lenguaje simple (oficio/barrio), sin tono LinkedIn / "profesional".
class EligeCaminoWidget extends StatefulWidget {
  static const String routeName = 'EligeCamino';
  static const String routePath = '/elige-camino';

  const EligeCaminoWidget({super.key});

  static bool necesitaElegir() {
    final data = UserSession().datosCompletos;
    if (data == null) return false;
    final camino = (data['camino_elegido'] ?? '').toString().trim();
    if (camino.isNotEmpty) return false;
    final esPrestador =
        data['es_trabajador'] == true || data['rol'] == 'trabajador';
    if (esPrestador) return false;
    return true;
  }

  @override
  State<EligeCaminoWidget> createState() => _EligeCaminoWidgetState();
}

class _EligeCaminoWidgetState extends State<EligeCaminoWidget> {
  static const Color _cliente = Color(0xFF734BE4);
  static const Color _prestador = Color(0xFF28B5CD);

  bool _saving = false;

  Future<void> _elegir(String camino, {required bool quiereOfrecer}) async {
    if (_saving) return;
    setState(() => _saving = true);

    final uid = UserSession().uid;
    try {
      if (uid != null && uid.isNotEmpty) {
        final patch = <String, dynamic>{
          'camino_elegido': camino,
          'es_trabajador': quiereOfrecer,
          'updated_at': FieldValue.serverTimestamp(),
        };
        if (quiereOfrecer) {
          patch['rol'] = 'trabajador';
        }
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .set(patch, SetOptions(merge: true));

        final data =
            Map<String, dynamic>.from(UserSession().datosCompletos ?? {});
        data['camino_elegido'] = camino;
        data['es_trabajador'] = quiereOfrecer;
        if (quiereOfrecer) data['rol'] = 'trabajador';
        UserSession().datosCompletos = data;
        UserSession().invalidateHomeCache();
      }
    } catch (e) {
      debugPrint('EligeCamino save error: $e');
      final data =
          Map<String, dynamic>.from(UserSession().datosCompletos ?? {});
      data['camino_elegido'] = camino;
      data['es_trabajador'] = quiereOfrecer;
      if (quiereOfrecer) data['rol'] = 'trabajador';
      UserSession().datosCompletos = data;
    }

    if (!mounted) return;

    if (quiereOfrecer) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EligeOficioWidget()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePageWidget(initialModoPrestador: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = UserSession().nombreCompleto.split(' ').first;
    final saludo = nombre.isNotEmpty ? 'Hola, $nombre' : 'Hola';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                saludo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '¿Qué querés hacer?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 36),
              _CaminoCard(
                color: _cliente,
                icon: Icons.search_rounded,
                titulo: 'Necesito un trabajo',
                subtitulo: 'Busco a alguien de confianza',
                enabled: !_saving,
                onTap: () => _elegir('busco', quiereOfrecer: false),
              ),
              const SizedBox(height: 16),
              _CaminoCard(
                color: _prestador,
                icon: Icons.handyman_rounded,
                titulo: 'Quiero trabajar',
                subtitulo: 'Ofrezco mis servicios',
                enabled: !_saving,
                onTap: () => _elegir('ofrezo', quiereOfrecer: true),
              ),
              const Spacer(),
              if (_saving)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: CircularProgressIndicator(),
                  ),
                ),
              const Text(
                'Después podés cambiar esta opción',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaminoCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final bool enabled;
  final VoidCallback onTap;

  const _CaminoCard({
    required this.color,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: color.withOpacity(0.25),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
