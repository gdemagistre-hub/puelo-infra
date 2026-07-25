import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_session.dart';
import 'Domicilioflotante.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';

class SolicitarValidacionWidget extends StatefulWidget {
  const SolicitarValidacionWidget({super.key});

  @override
  State<SolicitarValidacionWidget> createState() =>
      _SolicitarValidacionWidgetState();
}

class _SolicitarValidacionWidgetState extends State<SolicitarValidacionWidget> {
  // Validaciones suman a la confianza del prestador
  static const Color primaryColor = AppColors.prestador;
  static const Color accentColor = Color(0xFFE6F7FA);
  static const Color textColor = AppColors.text;

  bool _loading = true;
  bool _tieneDomicilio = false;
  String _nombreCompleto = '';
  int _validacionesCount = 0;

  @override
  void initState() {
    super.initState();
    _verificarPerfil();
  }

  Future<void> _verificarPerfil() async {
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final calle = (data['calle'] ?? '').toString().trim();
        final numero = (data['numero'] ?? '').toString().trim();
        final geo = data['direccion_geo'] as Map<String, dynamic>?;
        final tieneGeo = geo != null &&
            (geo['localidad_id'] != null ||
                (geo['localidad_nombre'] ?? '').toString().isNotEmpty);

        _nombreCompleto =
            '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
        _tieneDomicilio =
            calle.isNotEmpty && numero.isNotEmpty && tieneGeo;

        final vals = data['validaciones_recibidas'] as List<dynamic>? ?? [];
        _validacionesCount = vals.length;
      }
    } catch (e) {
      debugPrint('Error verificando domicilio: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  String _generarLink(String idDocumento) {
    return 'https://lifewalletpuelo.web.app/#/validarDomicilio?id=$idDocumento';
  }

  Future<void> _compartirPorWhatsApp(String idDocumento) async {
    final link = _generarLink(idDocumento);
    final nombre = _nombreCompleto.isNotEmpty ? _nombreCompleto : 'un vecino';
    final mensaje = Uri.encodeComponent(
      'Hola, soy $nombre. ¿Me ayudás con algo rápido?\n\n'
      'En Puelo (app de oficios) me piden que alguien del barrio confirme '
      'que me conoce y que la dirección es real. Son 3 preguntas, menos de un minuto.\n\n'
      '$link\n\n¡Gracias!',
    );
    final url = Uri.parse('https://wa.me/?text=$mensaje');

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.platformDefault,
      );

      if (!launched) {
        await Clipboard.setData(ClipboardData(text: link));
        _mostrarAlerta(
          'No se pudo abrir WhatsApp. El enlace se copió al portapapeles.',
        );
      }
    } catch (e) {
      debugPrint('Error abriendo WhatsApp: $e');
      await Clipboard.setData(ClipboardData(text: link));
      _mostrarAlerta(
        'No se pudo abrir WhatsApp. El enlace se copió al portapapeles.',
      );
    }
  }

  Future<void> _copiarEnlaceAlPortapapeles(String idDocumento) async {
    final link = _generarLink(idDocumento);
    try {
      await Clipboard.setData(ClipboardData(text: link));
      _mostrarAlerta('¡Enlace copiado!');
    } catch (e) {
      debugPrint('Error copiando al portapapeles: $e');
      _mostrarAlerta('No se pudo copiar el enlace. Intentá de nuevo.');
    }
  }

  void _mostrarAlerta(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final uid = UserSession().uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: textColor,
          elevation: 0,
          title: const Text('Validación'),
        ),
        body: const Center(child: Text('Error de sesión. Volvé a ingresar.')),
      );
    }

    if (!_tieneDomicilio) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Pedir validación'),
          backgroundColor: Colors.white,
          foregroundColor: textColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                const Text(
                  'Primero cargá tu domicilio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para que un vecino o conocido pueda confirmar tu dirección, '
                  'necesitás tener calle, número y localidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DomicilioFlotanteWidget(),
                      ),
                    );
                    await _verificarPerfil();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cargar domicilio'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Pedir validación'),
        backgroundColor: Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppCopy.validacionTercerosHint,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Alguien del barrio o de confianza confirma que te conoce. '
                    'Eso genera mucha más confianza que un formulario solo.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  if (_validacionesCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ya tenés $_validacionesCount validación(es) recibida(s).',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Tu enlace está listo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Mandáselo por WhatsApp a alguien que te conozca. '
                          'Le toma menos de un minuto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _compartirPorWhatsApp(uid),
                                icon: const Icon(Icons.chat, size: 16),
                                label: const Text('WhatsApp'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.whatsapp,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _copiarEnlaceAlPortapapeles(uid),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Copiar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  side: const BorderSide(
                                    color: primaryColor,
                                    width: 1.5,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: primaryColor,
                              child: Text(
                                _nombreCompleto.isNotEmpty
                                    ? _nombreCompleto[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _nombreCompleto.isNotEmpty
                                    ? _nombreCompleto
                                    : 'Tu perfil',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '¿Qué hace quien recibe el enlace?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Responde unas preguntas simples: si te conoce y si la dirección es correcta. '
                          'No pide tarjetas ni datos bancarios. Es apoyo de quien te conoce en la vida real.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
