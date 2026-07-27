import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'Homepage.dart';
import 'scoring_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';

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

  static const Map<String, String> _labelOficio = {
    'electricidad': 'Electricista',
    'plomeria': 'Plomería',
    'gasista': 'Gasista',
    'carpinteria': 'Carpintería',
    'pintura': 'Pintura',
    'albanileria': 'Construcción',
    'jardineria': 'Jardinería',
    'limpieza': 'Limpieza',
  };

  String _labelProf(dynamic p) {
    final k = p.toString().toLowerCase().trim();
    return _labelOficio[k] ?? p.toString();
  }

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

  Future<void> _contactarWhatsApp(String telefono, String nombre) async {
    final tel = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    final mensaje = Uri.encodeComponent(
      'Hola $nombre, vi tu tarjeta en Puelo y me gustaría hacerte una consulta.',
    );
    final url = Uri.parse('https://wa.me/$tel?text=$mensaje');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _mostrarAlerta('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _realizarLlamada(String telefono) async {
    final tel = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('tel:$tel');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _mostrarAlerta('No se pudo iniciar la llamada');
    }
  }

  Future<void> _compartirPorWhatsApp(String nombre, String idDocumento) async {
    final linkTarjeta =
        'https://lifewalletpuelo.web.app/#/tarjetaDigital?id=$idDocumento';
    final mensajeShared = Uri.encodeComponent(
      '¡Hola! Te comparto mi tarjeta de servicios en Puelo:\n\n$linkTarjeta',
    );
    final url = Uri.parse('https://wa.me/?text=$mensajeShared');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _mostrarAlerta('No se pudo abrir WhatsApp para compartir');
    }
  }

  void _copiarEnlaceAlPortapapeles(String idDocumento) {
    final linkTarjeta =
        'https://lifewalletpuelo.web.app/#/tarjetaDigital?id=$idDocumento';
    Clipboard.setData(ClipboardData(text: linkTarjeta));
    _mostrarAlerta('¡Enlace copiado al portapapeles!');
  }

  void _mostrarAlerta(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _mostrarExplicacionBadge(String? badge) {
    final label = ScoringService.labelBadge(badge);
    final texto = ScoringService.explicacionBadge(badge);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                label.isEmpty ? 'Sin identificador' : label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppCopy.badgeTapHint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeChip(String? badge) {
    final label = ScoringService.labelBadge(badge);
    if (label.isEmpty) return const SizedBox.shrink();
    final c = ScoringService.coloresBadge(badge);
    return InkWell(
      onTap: () => _mostrarExplicacionBadge(badge),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Color(c.background),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(c.foreground).withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(c.foreground),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline,
              size: 14,
              color: Color(c.foreground).withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                const Text(
                  'No se encontró la tarjeta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El enlace parece no ser válido o la tarjeta ya no está disponible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _resolvedRef!.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Ocurrió un error al cargar la información')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('La tarjeta seleccionada no existe.')),
          );
        }

        final datos = snapshot.data!.data() as Map<String, dynamic>;
        final String nombre = datos['nombre'] ?? '';
        final String apellido = datos['apellido'] ?? '';
        final String nombreComercial = datos['nombre_comercial'] ?? '';
        final String telefono = (datos['telefono'] ?? '').toString();
        final List<dynamic> profesiones = datos['profesiones'] ?? [];
        final String docId = snapshot.data!.id;
        final String? badge = datos['badge_prestador'] as String?;
        final String? urlFoto =
            (datos['url_foto_perfil'] ?? datos['foto_perfil'])?.toString();

        final Map<String, dynamic>? zonasCoberturaMap =
            datos['zonas_cobertura'];
        List<String> zonasLista = [];
        if (zonasCoberturaMap != null &&
            zonasCoberturaMap['localidades'] != null) {
          final List<dynamic> locs = zonasCoberturaMap['localidades'];
          zonasLista = locs.map((e) {
            if (e is Map) {
              return (e['nombre'] ?? e['localidad_nombre'] ?? '').toString();
            }
            return e.toString();
          }).where((s) => s.isNotEmpty).toList();
        }

        final double promedio =
            (datos['promedioEstrellas'] as num?)?.toDouble() ?? 0.0;
        final int cantidadEvaluadores =
            (datos['cantidadEvaluadores'] as num?)?.toInt() ?? 0;

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
                  MaterialPageRoute(
                      builder: (context) => const HomePageWidget()),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              'Compartila para presentarte con nuevos clientes.',
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
                                    onPressed: () => _compartirPorWhatsApp(
                                      '$nombre $apellido',
                                      docId,
                                    ),
                                    icon: const Icon(Icons.share_rounded,
                                        size: 16),
                                    label: const Text(AppCopy.ctaCompartirTarjeta),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _copiarEnlaceAlPortapapeles(docId),
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 16),
                                    label: const Text('Copiar enlace'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: const BorderSide(
                                        color: primaryColor,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
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
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
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
                                  backgroundImage:
                                      (urlFoto != null && urlFoto.isNotEmpty)
                                          ? NetworkImage(urlFoto)
                                          : null,
                                  child: (urlFoto == null || urlFoto.isEmpty)
                                      ? Text(
                                          nombre.isNotEmpty
                                              ? nombre[0].toUpperCase()
                                              : 'P',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombreComercial.isNotEmpty
                                            ? nombreComercial
                                            : '$nombre $apellido',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: textColor,
                                        ),
                                      ),
                                      if (nombreComercial.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '$nombre $apellido',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFFFB000),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              cantidadEvaluadores > 0
                                                  ? '${promedio.toStringAsFixed(1)} ($cantidadEvaluadores evaluaciones)'
                                                  : 'Sin evaluaciones aún',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (badge != null &&
                                          ScoringService.labelBadge(badge)
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        _buildBadgeChip(badge),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            if (profesiones.isNotEmpty) ...[
                              const Text(
                                'Servicios que ofrece',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: profesiones.map((prof) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _labelProf(prof),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],

                            if (zonasLista.isNotEmpty) ...[
                              const Text(
                                'Zonas de cobertura',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      zonasLista.join(', '),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: telefono.isEmpty
                                  ? null
                                  : () =>
                                      _contactarWhatsApp(telefono, nombre),
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 18,
                              ),
                              label: const Text(AppCopy.ctaWhatsApp),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.whatsapp,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: IconButton(
                              onPressed: telefono.isEmpty
                                  ? null
                                  : () => _realizarLlamada(telefono),
                              icon: const Icon(
                                Icons.phone_enabled_rounded,
                                color: primaryColor,
                                size: 22,
                              ),
                              padding: const EdgeInsets.all(16),
                              tooltip: AppCopy.ctaLlamar,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('trabajos')
                            .where('usuario_id', isEqualTo: _resolvedRef!.id)
                            .get(),
                        builder: (context, trabajosSnapshot) {
                          if (trabajosSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            );
                          }

                          final List<String> todasLasImagenes = [];

                          if (trabajosSnapshot.hasData) {
                            for (final doc in trabajosSnapshot.data!.docs) {
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              if (data['imagenes'] != null) {
                                final imgs =
                                    data['imagenes'] as List<dynamic>;
                                todasLasImagenes.addAll(
                                  imgs.map((e) => e.toString()),
                                );
                              }
                            }
                          }

                          return FutureBuilder<QuerySnapshot?>(
                            future: todasLasImagenes.isNotEmpty
                                ? Future.value(null)
                                : FirebaseFirestore.instance
                                    .collection('trabajos')
                                    .limit(80)
                                    .get(),
                            builder: (context, fallbackSnap) {
                              if (todasLasImagenes.isEmpty &&
                                  fallbackSnap.hasData) {
                                final currentId = _resolvedRef!.id;
                                for (final doc
                                    in fallbackSnap.data!.docs) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final rawRef = data['trabajadorRef'];
                                  final uidCampo =
                                      data['usuario_id']?.toString();
                                  bool coincide = false;
                                  if (uidCampo != null &&
                                      uidCampo == currentId) {
                                    coincide = true;
                                  } else if (rawRef is DocumentReference) {
                                    coincide = rawRef.id == currentId;
                                  } else if (rawRef is String) {
                                    coincide = rawRef == currentId ||
                                        rawRef.endsWith('/$currentId');
                                  }
                                  if (coincide &&
                                      data['imagenes'] != null) {
                                    final imgs =
                                        data['imagenes'] as List<dynamic>;
                                    todasLasImagenes.addAll(
                                      imgs.map((e) => e.toString()),
                                    );
                                  }
                                }
                              }

                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Trabajos mostrados',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${todasLasImagenes.length} FOTOS',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (todasLasImagenes.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: const Text(
                                        'Todavía no hay fotos de trabajos en el portfolio.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  else
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 1.1,
                                      ),
                                      itemCount: todasLasImagenes.length,
                                      itemBuilder: (context, index) {
                                        return ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Image.network(
                                            todasLasImagenes[index],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              );
                            },
                          );
                        },
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
