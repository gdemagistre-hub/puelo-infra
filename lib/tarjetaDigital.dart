import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Homepage.dart';
import 'scoring_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';
import 'user_session.dart';

class TarjetaDigitalWidget extends StatefulWidget {
  const TarjetaDigitalWidget({
    super.key,
    this.usuarioRef,
  });

  final DocumentReference? usuarioRef;

  static const String routeName = 'tarjetaDigital';
  static const String routePath = '/tarjetaDigital';

  @override
  State<TarjetaDigitalWidget> createState() => _TarjetaDigitalWidgetState();
}

class _TarjetaDigitalWidgetState extends State<TarjetaDigitalWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  DocumentReference? _resolvedRef;
  bool _loading = true;

  static const Color primaryColor = AppColors.prestador;
  static const Color accentColor = Color(0xFFE6F7FA);
  static const Color textColor = AppColors.text;

  @override
  void initState() {
    super.initState();
    _resolveReference();
  }

  void _resolveReference() {
    if (widget.usuarioRef != null) {
      _resolvedRef = widget.usuarioRef;
      _loading = false;
      return;
    }
    try {
      final uri = Uri.base;
      String? id;
      if (uri.queryParameters.containsKey('id')) {
        id = uri.queryParameters['id'];
      } else {
        final fragment = uri.fragment;
        if (fragment.contains('?')) {
          final fragmentUri = Uri.parse(fragment);
          if (fragmentUri.queryParameters.containsKey('id')) {
            id = fragmentUri.queryParameters['id'];
          }
        }
      }
      if (id != null && id.isNotEmpty) {
        _resolvedRef = FirebaseFirestore.instance.collection('usuarios').doc(id);
      }
    } catch (e) {
      debugPrint('Error al intentar leer la URL nativa: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }
    if (_resolvedRef == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Text('No se encontró la tarjeta', style: TextStyle(color: textColor)),
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: _resolvedRef!.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final datos = snapshot.data!.data() as Map<String, dynamic>;
        final String docId = snapshot.data!.id;
        final bool esPropietario = UserSession().uid == docId;
        final String nombre = datos['nombre'] ?? '';
        final String apellido = datos['apellido'] ?? '';
        final String nombreComercial = datos['nombre_comercial'] ?? '';
        final String telefono = (datos['telefono'] ?? '').toString();
        final String? urlFoto = (datos['url_foto_perfil'] ?? datos['foto_perfil'])?.toString();

        return Scaffold(
          key: scaffoldKey,
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: textColor,
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePageWidget()),
                  (route) => false,
                );
              },
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 550),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (esPropietario) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Tarjeta de servicios activa',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Compartila con clientes nuevos por WhatsApp.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF475569), fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final link = 'https://lifewalletpuelo.web.app/#/tarjetaDigital?id=$docId';
                                        final msg = Uri.encodeComponent('¡Hola! Te comparto mi tarjeta de servicios en Puelo:\n\n$link');
                                        launchUrl(Uri.parse('https://wa.me/?text=$msg'), mode: LaunchMode.externalApplication);
                                      },
                                      icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                                      label: const Text(AppCopy.ctaCompartirTarjeta, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        final link = 'https://lifewalletpuelo.web.app/#/tarjetaDigital?id=$docId';
                                        Clipboard.setData(ClipboardData(text: link));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('¡Enlace copiado al portapapeles!'), behavior: SnackBarBehavior.floating),
                                        );
                                      },
                                      icon: const Icon(Icons.copy_rounded, size: 15),
                                      label: const Text('Copiar enlace', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: const BorderSide(color: primaryColor, width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: primaryColor,
                                  backgroundImage: (urlFoto != null && urlFoto.isNotEmpty) ? NetworkImage(urlFoto) : null,
                                  child: (urlFoto == null || urlFoto.isEmpty)
                                      ? Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white))
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombreComercial.isNotEmpty ? nombreComercial : '$nombre $apellido',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
                                      ),
                                      if (nombreComercial.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('$nombre $apellido', style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (telefono.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            final tel = telefono.replaceAll(RegExp(r'[^\d+]'), '');
                            final mensaje = Uri.encodeComponent('Hola $nombre, vi tu tarjeta en Puelo y me gustaría hacerte una consulta.');
                            launchUrl(Uri.parse('https://wa.me/$tel?text=$mensaje'), mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: const Text(AppCopy.ctaWhatsApp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.whatsapp,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
