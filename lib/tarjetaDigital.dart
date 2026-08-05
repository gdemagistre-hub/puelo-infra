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


  Future<List<_TrabajoFotoItem>> _cargarFotosTrabajos(String userId) async {
    final items = <_TrabajoFotoItem>[];

    void absorb(QuerySnapshot snap) {
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final rawRef = data['trabajadorRef'];
        final uidCampo = data['usuario_id']?.toString();
        bool coincide = uidCampo == userId;
        if (!coincide && rawRef is DocumentReference) {
          coincide = rawRef.id == userId;
        } else if (!coincide && rawRef is String) {
          coincide = rawRef == userId || rawRef.endsWith('/$userId');
        }
        if (!coincide) continue;
        final imgs = (data['imagenes'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
        if (imgs.isEmpty) continue;
        final servicio = (data['profesion'] ??
                data['oficio'] ??
                data['servicio'] ??
                data['nombre_servicio'] ??
                '')
            .toString()
            .trim();
        DateTime? fecha;
        final f = data['fechaCarga'] ??
            data['fecha'] ??
            data['created_at'] ??
            data['fecha_evaluacion'];
        if (f is Timestamp) fecha = f.toDate();
        if (f is String) fecha = DateTime.tryParse(f);
        final mesAnio = fecha != null ? _formatoMesAnio(fecha) : '';
        for (final url in imgs) {
          items.add(_TrabajoFotoItem(
            url: url,
            servicio: servicio.isEmpty ? 'Servicio' : _labelServicio(servicio),
            mesAnio: mesAnio,
            trabajoId: doc.id,
          ));
        }
      }
    }

    try {
      final q1 = await FirebaseFirestore.instance
          .collection('trabajos')
          .where('usuario_id', isEqualTo: userId)
          .get();
      absorb(q1);
      if (items.isEmpty) {
        final q2 = await FirebaseFirestore.instance
            .collection('trabajos')
            .limit(100)
            .get();
        absorb(q2);
      }
    } catch (e) {
      debugPrint('Error cargando trabajos: $e');
    }
    return items;
  }

  String _formatoMesAnio(DateTime d) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${meses[d.month - 1]} ${d.year}';
  }

  String _labelServicio(String raw) {
    if (raw.isEmpty) return 'Servicio';
    final t = raw.replaceAll('_', ' ').trim();
    if (t.isEmpty) return 'Servicio';
    return t[0].toUpperCase() + t.substring(1);
  }

  void _abrirFotoGrande(
    BuildContext context,
    List<_TrabajoFotoItem> items,
    int index,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) {
        return _FotoGrandeViewer(
          items: items,
          initialIndex: index,
        );
      },
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
        final bool esPropietario = UserSession().uid == docId;
        final String? badge = datos['badge_prestador'] as String?;
        final scoringMap = datos['scoring'];
        final String? nivelConfianza = scoringMap is Map
            ? (scoringMap['nivel_confianza'] as String?)
            : null;
        final int? scoreIdentidad = scoringMap is Map
            ? (scoringMap['score_identidad'] as num?)?.toInt()
            : null;
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
                      // Solo el dueño ve el bloque de compartir (iconos + leyenda)
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
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _compartirPorWhatsApp(
                                        '$nombre $apellido',
                                        docId,
                                      ),
                                      icon: const FaIcon(
                                        FontAwesomeIcons.whatsapp,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        AppCopy.ctaCompartirTarjeta,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 10,
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
                                    flex: 3,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _copiarEnlaceAlPortapapeles(docId),
                                      icon: const Icon(Icons.copy_rounded,
                                          size: 15),
                                      label: const Text(
                                        'Copiar enlace',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: const BorderSide(
                                          color: primaryColor,
                                          width: 1.5,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 8,
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
                      ],

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
                                      if (badge != null && badge.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        _buildBadgeChip(badge),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (profesiones.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: profesiones.map((p) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _labelProf(p),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (promedio > 0 || cantidadEvaluadores > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: Colors.amber.shade600, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    promedio.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '($cantidadEvaluadores)',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (zonasLista.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      zonasLista.join(', '),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
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

                      // CTA principal: WhatsApp (siempre visible para clientes)
                      if (telefono.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () =>
                              _contactarWhatsApp(telefono, nombre),
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 18),
                          label: const Text(AppCopy.ctaWhatsApp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.whatsapp,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),

                      if (telefono.isNotEmpty) const SizedBox(height: 12),

                      if (telefono.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _realizarLlamada(telefono),
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: const Text('Llamar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: const BorderSide(color: primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),

                      const SizedBox(height: 28),

                      // Portfolio de trabajos
                      const Text(
                        'Trabajos realizados',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<_TrabajoFotoItem>>(
                        future: _cargarFotosTrabajos(docId),
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final items = snap.data ?? [];
                          if (items.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.grey.shade200),
                              ),
                              child: Text(
                                esPropietario
                                    ? 'Todavía no cargaste fotos de trabajos. Subí algunas desde tu perfil para que los clientes las vean.'
                                    : 'Este prestador aún no publicó fotos de trabajos realizados.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SpacedGridDelegate(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1,
                            ),
                            itemCount: items.length > 6 ? 6 : items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return GestureDetector(
                                onTap: () => _abrirFotoGrande(
                                    context, items, index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        item.url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                              Icons.broken_image_outlined),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.fromLTRB(
                                              8, 16, 8, 8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.7),
                                              ],
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                item.servicio,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (item.mesAnio.isNotEmpty)
                                                Text(
                                                  item.mesAnio,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 32),
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

class _TrabajoFotoItem {
  final String url;
  final String servicio;
  final String mesAnio;
  final String trabajoId;

  _TrabajoFotoItem({
    required this.url,
    required this.servicio,
    required this.mesAnio,
    required this.trabajoId,
  });
}

class SpacedGridDelegate extends SliverGridDelegate {
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  const SpacedGridDelegate({
    required this.crossAxisCount,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double usableWidth =
        constraints.crossAxisExtent - (crossAxisCount - 1) * crossAxisSpacing;
    final double itemWidth = usableWidth / crossAxisCount;
    final double itemHeight = itemWidth / childAspectRatio;
    return SpacedGridLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: itemHeight + mainAxisSpacing,
      crossAxisStride: itemWidth + crossAxisSpacing,
      childMainAxisExtent: itemHeight,
      childCrossAxisExtent: itemWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SpacedGridDelegate oldDelegate) {
    return oldDelegate.crossAxisCount != crossAxisCount ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.childAspectRatio != childAspectRatio;
  }
}

class SpacedGridLayout extends SpacedGridLayoutBase {
  SpacedGridLayout({
    required super.crossAxisCount,
    required super.mainAxisStride,
    required super.crossAxisStride,
    required super.childMainAxisExtent,
    required super.childCrossAxisExtent,
    required super.reverseCrossAxis,
  });
}

abstract class SpacedGridLayoutBase extends SliverGridLayout {
  final int crossAxisCount;
  final double mainAxisStride;
  final double crossAxisStride;
  final double childMainAxisExtent;
  final double childCrossAxisExtent;
  final bool reverseCrossAxis;

  SpacedGridLayoutBase({
    required this.crossAxisCount,
    required this.mainAxisStride,
    required this.crossAxisStride,
    required this.childMainAxisExtent,
    required this.childCrossAxisExtent,
    required this.reverseCrossAxis,
  });

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    return crossAxisCount * (scrollOffset ~/ mainAxisStride);
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    final mainAxisCount = (scrollOffset / mainAxisStride).ceil();
    return (mainAxisCount * crossAxisCount) - 1;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final double crossAxisStart =
        (index % crossAxisCount) * crossAxisStride;
    return SpacedGridGeometry(
      scrollOffset: (index ~/ crossAxisCount) * mainAxisStride,
      crossAxisOffset: reverseCrossAxis
          ? crossAxisCount * crossAxisStride -
              crossAxisStart -
              childCrossAxisExtent
          : crossAxisStart,
      mainAxisExtent: childMainAxisExtent,
      crossAxisExtent: childCrossAxisExtent,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    final mainAxisCount = ((childCount - 1) ~/ crossAxisCount) + 1;
    return mainAxisCount * mainAxisStride - mainAxisSpacing;
  }

  double get mainAxisSpacing => mainAxisStride - childMainAxisExtent;
}

class SpacedGridGeometry extends SliverGridGeometry {
  SpacedGridGeometry({
    required super.scrollOffset,
    required super.crossAxisOffset,
    required super.mainAxisExtent,
    required super.crossAxisExtent,
  });
}

class _FotoGrandeViewer extends StatefulWidget {
  final List<_TrabajoFotoItem> items;
  final int initialIndex;

  const _FotoGrandeViewer({
    required this.items,
    required this.initialIndex,
  });

  @override
  State<_FotoGrandeViewer> createState() => _FotoGrandeViewerState();
}

class _FotoGrandeViewerState extends State<_FotoGrandeViewer> {
  late PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final item = widget.items[i];
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      item.url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    widget.items[_index].servicio,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.items[_index].mesAnio.isNotEmpty)
                    Text(
                      widget.items[_index].mesAnio,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${_index + 1} / ${widget.items.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
