import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_session.dart';
import 'completar_perfil.dart';

class SolicitarValidacionWidget extends StatefulWidget {
  const SolicitarValidacionWidget({super.key});

  @override
  State<SolicitarValidacionWidget> createState() => _SolicitarValidacionWidgetState();
}

class _SolicitarValidacionWidgetState extends State<SolicitarValidacionWidget> {
  final primaryColor = const Color(0xFF0F52BA);
  final accentColor = const Color(0xFFE8F0FE);
  final textColor = const Color(0xFF1E293B);

  bool _loading = true;
  bool _tieneDomicilio = false;
  String _nombreCompleto = '';

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
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final calle = (data['calle'] ?? '').toString().trim();
        final numero = (data['numero'] ?? '').toString().trim();
        final geo = data['direccion_geo'] as Map<String, dynamic>?;
        final tieneGeo = geo != null && geo['localidad_id'] != null;

        _nombreCompleto = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
        _tieneDomicilio = calle.isNotEmpty && numero.isNotEmpty && tieneGeo;
      }
    } catch (e) {
      debugPrint('Error verificando domicilio: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _compartirPorWhatsApp(String idDocumento) async {
    final link = 'https://lifewalletpuelo.web.app/#/validarDomicilio?id=$idDocumento';
    final mensaje = Uri.encodeComponent(
        '¡Hola! Te pido un favor: ayudame a validar mi domicilio en Puelo. '
        'Solo te toma 1 minuto y aumenta la confianza de la comunidad.\n\n$link');
    final url = Uri.parse('https://wa.me/?text=$mensaje');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _mostrarAlerta('No se pudo abrir WhatsApp');
    }
  }

  void _copiarEnlaceAlPortapapeles(String idDocumento) {
    final link = 'https://lifewalletpuelo.web.app/#/validarDomicilio?id=$idDocumento';
    Clipboard.setData(ClipboardData(text: link));
    _mostrarAlerta('¡Enlace copiado al portapapeles!');
  }

  void _mostrarAlerta(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final uid = UserSession().uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(backgroundColor: primaryColor, foregroundColor: Colors.white, title: const Text('Validación de perfil')),
        body: const Center(child: Text('Error de sesión. Volvé a ingresar.')),
      );
    }

    if (!_tieneDomicilio) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Pedir validación'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                const Text(
                  'Completá primero tu domicilio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para poder solicitar validaciones necesitás tener cargada tu dirección completa (calle, número y localidad).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const CompletarPerfilWidget()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ir a Mis datos personales'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Pedir validación del perfil'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  // Panel de acciones (idéntico en estilo a la tarjeta digital)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Tu solicitud de validación está lista',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Compartí este enlace con personas que conozcan tu domicilio. Ellas confirmarán que te conocen y validarán la dirección.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF475569), fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _compartirPorWhatsApp(uid),
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: const Text('Enviar WhatsApp'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copiarEnlaceAlPortapapeles(uid),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Copiar Enlace'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  side: BorderSide(color: primaryColor, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
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
                                _nombreCompleto.isNotEmpty ? _nombreCompleto[0].toUpperCase() : 'P',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _nombreCompleto.isNotEmpty ? _nombreCompleto : 'Tu perfil',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '¿Qué van a hacer quienes reciban el enlace?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Confirmarán si te conocen.\n'
                          '2. Elegirán tu domicilio real entre 3 opciones.\n'
                          '3. Indicarán hace cuánto vivís ahí (dato solo informativo).',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
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
