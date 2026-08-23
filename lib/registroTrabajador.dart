import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Homepage.dart';
import 'user_session.dart';
import 'prestador_list_fields.dart';
import 'especialidadesLaboralesflotante.dart';
import 'ZonaDeTrabajoflotante.dart';
import 'tarjetaDigital.dart';
import 'theme/app_colors.dart';

/// Onboarding prestador canónico:
/// 1) Especialidades → 2) Zona de trabajo → 3) Tarjeta / WhatsApp
///
/// Las pantallas de detalle son las flotantes ya alineadas al look prestador.
/// Este archivo solo orquesta el progreso (no duplica formularios).
///
/// Etapa 5.5: salir del hub siempre a Home en modo prestador
/// (tips / siguiente paso visibles). Tras ver la tarjeta: snackbar + CTA.
class RegistroTrabajadorWidget extends StatefulWidget {
  const RegistroTrabajadorWidget({super.key});

  static const String routeName = 'registroTrabajador';
  static const String routePath = '/registroTrabajador';

  @override
  State<RegistroTrabajadorWidget> createState() =>
      _RegistroTrabajadorWidgetState();
}

class _RegistroTrabajadorWidgetState extends State<RegistroTrabajadorWidget> {
  static const Color _primary = AppColors.prestador;

  bool _loading = true;
  bool _paso1Ok = false; // profesiones
  bool _paso2Ok = false; // zonas
  bool _paso3Visto = false; // volvió de la tarjeta en esta sesión

  @override
  void initState() {
    super.initState();
    _refrescarEstado();
  }

  Future<void> _refrescarEstado() async {
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final data = doc.data() ?? {};

      final profesiones = data['profesiones'] as List<dynamic>? ?? [];
      final zonas = data['zonas_cobertura'] as Map<String, dynamic>?;
      final localidades = zonas?['localidades'] as List<dynamic>? ?? [];

      setState(() {
        _paso1Ok = profesiones.isNotEmpty;
        _paso2Ok = localidades.isNotEmpty ||
            (zonas?['provincia_id'] != null &&
                (zonas?['provincia_id'].toString().isNotEmpty ?? false));
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error estado onboarding: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _marcarPrestadorEnSesion({bool persist = true}) async {
    final session = UserSession();
    final uid = session.uid;
    final mem = <String, dynamic>{
      ...(session.datosCompletos ?? {}),
      'es_trabajador': true,
      'rol': 'trabajador',
      'camino_elegido': 'ofrezo',
    };
    session.datosCompletos = mem;
    session.invalidateHomeCache();
    session.persistHomeModoPrestador(true);
    if (!persist || uid == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set(
        {
          'es_trabajador': true,
          'rol': 'trabajador',
          'camino_elegido': 'ofrezo',
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('marcarPrestador persist error: $e');
    }
  }

  void _irAlInicio() {
    _marcarPrestadorEnSesion();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePageWidget(initialModoPrestador: true),
      ),
      (route) => false,
    );
  }

  Future<void> _abrirPaso1() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EspecialidadesLaboralesFlotanteWidget(),
      ),
    );
    await _refrescarEstado();
  }

  Future<void> _abrirPaso2() async {
    if (!_paso1Ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero cargá al menos un oficio (paso 1).'),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ZonaDeTrabajoFlotanteWidget(),
      ),
    );
    await _refrescarEstado();
  }

  Future<void> _abrirPaso3() async {
    if (!_paso1Ok || !_paso2Ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completá oficios y zona antes de ver la tarjeta.'),
        ),
      );
      return;
    }
    final uid = UserSession().uid;
    if (uid == null) return;

    // Asegurar flags prestador + list fields (Sprint 2)
    try {
      final session = UserSession();
      final patch = <String, dynamic>{
        'es_trabajador': true,
        'rol': 'trabajador',
        'camino_elegido': 'ofrezo',
        'updated_at': FieldValue.serverTimestamp(),
      };
      final base = {...(session.datosCompletos ?? {}), ...patch};
      patch.addAll(PrestadorListFields.build(data: base, touchTimestamp: true));
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set(patch, SetOptions(merge: true));
      session.datosCompletos = {...(session.datosCompletos ?? {}), ...patch};
      session.invalidateHomeCache();
    } catch (_) {}

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TarjetaDigitalWidget(
          usuarioRef:
              FirebaseFirestore.instance.collection('usuarios').doc(uid),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _paso3Visto = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: const Text(
          'Tarjeta lista. En el inicio vas a ver el siguiente paso para que te elijan.',
        ),
        action: SnackBarAction(
          label: 'Ir al inicio',
          textColor: Colors.white,
          onPressed: _irAlInicio,
        ),
      ),
    );
  }

  int get _pasosCompletos {
    var n = 0;
    if (_paso1Ok) n++;
    if (_paso2Ok) n++;
    if (_paso1Ok && _paso2Ok) n++; // paso 3 habilitado = “listo para tarjeta”
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final uid = UserSession().uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text('Iniciá sesión para configurar tus servicios.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Mis servicios'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Ir al inicio',
            icon: const Icon(Icons.home_rounded),
            onPressed: _irAlInicio,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Estás a 3 pasos de recibir pedidos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Completá oficios, zona y compartí tu tarjeta por WhatsApp.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),

                // Progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _pasosCompletos / 3,
                    minHeight: 8,
                    backgroundColor: _primary.withOpacity(0.12),
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_pasosCompletos de 3 listos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),

                _PasoCard(
                  numero: 1,
                  titulo: 'Especialidades',
                  subtitulo: _paso1Ok
                      ? 'Oficios cargados ✓'
                      : 'Qué servicios ofrecés',
                  completo: _paso1Ok,
                  onTap: _abrirPaso1,
                ),
                const SizedBox(height: 12),
                _PasoCard(
                  numero: 2,
                  titulo: 'Zona de trabajo',
                  subtitulo: _paso2Ok
                      ? 'Cobertura definida ✓'
                      : 'Dónde trabajás',
                  completo: _paso2Ok,
                  bloqueado: !_paso1Ok,
                  onTap: _abrirPaso2,
                ),
                const SizedBox(height: 12),
                _PasoCard(
                  numero: 3,
                  titulo: 'Tu tarjeta',
                  subtitulo: (_paso1Ok && _paso2Ok)
                      ? (_paso3Visto
                          ? 'Ya la viste — podés compartirla'
                          : 'Compartila por WhatsApp')
                      : 'Se habilita al completar 1 y 2',
                  completo: _paso1Ok && _paso2Ok && _paso3Visto,
                  bloqueado: !(_paso1Ok && _paso2Ok),
                  onTap: _abrirPaso3,
                  destacado: _paso1Ok && _paso2Ok && !_paso3Visto,
                ),

                const SizedBox(height: 28),
                if (_paso1Ok && _paso2Ok && _paso3Visto) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _irAlInicio,
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Ir al inicio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _abrirPaso3,
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Ver tarjeta de nuevo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else if (_paso1Ok && _paso2Ok)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _abrirPaso3,
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Ver y compartir mi tarjeta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    'Tip: con oficios + zona los clientes pueden encontrarte en el buscador.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 12),
                if (!(_paso1Ok && _paso2Ok && _paso3Visto))
                  TextButton(
                    onPressed: _irAlInicio,
                    child: const Text(
                      'Ir al inicio',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PasoCard extends StatelessWidget {
  final int numero;
  final String titulo;
  final String subtitulo;
  final bool completo;
  final bool bloqueado;
  final bool destacado;
  final VoidCallback onTap;

  const _PasoCard({
    required this.numero,
    required this.titulo,
    required this.subtitulo,
    required this.completo,
    required this.onTap,
    this.bloqueado = false,
    this.destacado = false,
  });

  static const Color _primary = AppColors.prestador;

  @override
  Widget build(BuildContext context) {
    final borderColor = destacado
        ? _primary
        : completo
            ? AppColors.success.withOpacity(0.5)
            : AppColors.border;

    return Opacity(
      opacity: bloqueado ? 0.55 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: bloqueado ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: destacado ? 1.5 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: completo
                        ? AppColors.success.withOpacity(0.15)
                        : _primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: completo
                      ? const Icon(Icons.check, color: AppColors.success, size: 22)
                      : Text(
                          '$numero',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _primary,
                            fontSize: 16,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
