import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'Homepage.dart';

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

  final primaryColor = const Color(0xFF0F52BA);
  final accentColor = const Color(0xFFE8F0FE);
  final textColor = const Color(0xFF1E293B);
  final cardBgColor = Colors.white;

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
      // Uso de Uri.base en lugar de dart:html para compatibilidad total con WASM y Móvil
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

    setState(() {
      _loading = false;
    });
  }

  Future<void> _contactarWhatsApp(String telefono, String nombre) async {
    final mensaje = Uri.encodeComponent(
        'Hola $nombre, vi tu Tarjeta Digital en Puelo y me gustaría hacerte una consulta.');
    final url = Uri.parse('https://wa.me/$telefono?text=$mensaje');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _mostrarAlerta('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _realizarLlamada(String telefono) async {
    final url = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _mostrarAlerta('No se pudo iniciar la llamada');
    }
  }

  Future<void> _compartirPorWhatsApp(String nombre, String idDocumento) async {
    final linkTarjeta = 'https://lifewalletpuelo.web.app/#/tarjetaDigital?id=$idDocumento';
    final mensajeShared = Uri.encodeComponent(
        '¡Hola! Te comparto mi Tarjeta Profesional Digital de Puelo con mi contacto y especialidades:\n\n$linkTarjeta');
    final url = Uri.parse('https://wa.me/?text=$mensajeShared');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _mostrarAlerta('No se pudo abrir WhatsApp para compartir');
    }
  }

  void _copiarEnlaceAlPortapapeles(String idDocumento) {
    final linkTarjeta = 'https://lifewalletpuelo.web.app/#/tarjetaDigital?id=$idDocumento';
    Clipboard.setData(ClipboardData(text: linkTarjeta));
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
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_resolvedRef == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'No se encontró la tarjeta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El enlace parece no ser válido o la tarjeta ya no está disponible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
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
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
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
        final String telefono = datos['telefono'] ?? '';
        final List<dynamic> profesiones = datos['profesiones'] ?? [];
        final String docId = snapshot.data!.id;

        // Extraemos las zonas de cobertura del nuevo esquema
        final Map<String, dynamic>? zonasCoberturaMap = datos['zonas_cobertura'];
        List<String> zonasLista = [];
        if (zonasCoberturaMap != null && zonasCoberturaMap['localidades'] != null) {
          final List<dynamic> locs = zonasCoberturaMap['localidades'];
          zonasLista = locs.map((e) => e['nombre'].toString()).toList();
        }

        // Nuevos campos calculados
        final double promedio = (datos['promedioEstrellas'] ?? 0.0).toDouble();
        final int cantidadEvaluadores = datos['cantidadEvaluadores'] ?? 0;

        return Scaffold(
          key: scaffoldKey,
          backgroundColor: const Color(0xFFF8FAFC),
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
                      // Panel de Acciones de Compartido
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Tu Tarjeta Digital está activa',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Usa estos accesos directos para presentarte con nuevos clientes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF475569), fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _compartirPorWhatsApp('$nombre $apellido', docId),
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
                                    onPressed: () => _copiarEnlaceAlPortapapeles(docId),
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
                      const SizedBox(height: 24),

                      // Tarjeta de Presentación
                      Container(
                        decoration: BoxDecoration(
                          color: cardBgColor,
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
                                  child: Text(
                                    nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombreComercial.isNotEmpty
                                            ? nombreComercial
                                            : '$nombre $apellido',
                                        style: TextStyle(
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
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      // Renderizado estético de valoración en el Perfil
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFFFFB000), size: 20),
                                          const SizedBox(width: 4),
                                          Text(
                                            cantidadEvaluadores > 0 
                                                ? '${promedio.toStringAsFixed(1)} ($cantidadEvaluadores evaluaciones)' 
                                                : 'Nuevo prestador',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            if (profesiones.isNotEmpty) ...[
                              const Text(
                                'Especialidades',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: profesiones.map((prof) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      prof.toString(),
                                      style: TextStyle(
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
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 16, color: primaryColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      zonasLista.join(', '),
                                      style: TextStyle(fontSize: 14, color: textColor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botones de Contacto
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _contactarWhatsApp(telefono, nombre),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              label: const Text('Escribir por WhatsApp'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            ),
                            child: IconButton(
                              onPressed: () => _realizarLlamada(telefono),
                              icon: Icon(Icons.phone_enabled_rounded, color: primaryColor, size: 22),
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Consulta de Trabajos Flexible
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('trabajos')
                            .get(),
                        builder: (context, trabajosSnapshot) {
                          if (trabajosSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          List<String> todasLasImagenes = [];
                          
                          if (trabajosSnapshot.hasData) {
                            final currentId = _resolvedRef!.id;
                            final currentPath = _resolvedRef!.path;

                            for (var doc in trabajosSnapshot.data!.docs) {
                              var data = doc.data() as Map<String, dynamic>;
                              var rawRef = data['trabajadorRef'];
                              bool coincide = false;

                              if (rawRef is DocumentReference) {
                                coincide = (rawRef.id == currentId);
                              } else if (rawRef is String) {
                                coincide = (rawRef == currentId || rawRef == currentPath);
                              }

                              if (coincide && data['imagenes'] != null) {
                                List<dynamic> imgs = data['imagenes'];
                                todasLasImagenes.addAll(imgs.map((e) => e.toString()));
                              }
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Trabajos realizados',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${todasLasImagenes.length} FOTOS',
                                      style: TextStyle(
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
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    'Este proveedor todavía no cargó imágenes de sus trabajos.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.1,
                                  ),
                                  itemCount: todasLasImagenes.length,
                                  itemBuilder: (context, index) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.network(
                                            todasLasImagenes[index],
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const Center(
                                                child: CircularProgressIndicator(),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.broken_image, color: Colors.grey),
                                              );
                                            },
                                          ),
                                          Container(
                                            color: Colors.black.withOpacity(0.05),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
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
