import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class TarjetaDigitalWidget extends StatefulWidget {
  const TarjetaDigitalWidget({
    super.key,
    required this.usuarioRef,
  });

  final DocumentReference? usuarioRef;

  static const String routeName = 'tarjetaDigital';
  static const String routePath = '/tarjetaDigital';

  @override
  State<TarjetaDigitalWidget> createState() => _TarjetaDigitalWidgetState();
}

class _TarjetaDigitalWidgetState extends State<TarjetaDigitalWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Paleta de colores unificada para Puelo
  final primaryColor = const Color(0xFF0F52BA); 
  final accentColor = const Color(0xFFE8F0FE);  
  final textColor = const Color(0xFF1E293B);    
  final subtitleColor = const Color(0xFF64748B); 

  // Lanzador nativo de enlace de WhatsApp
  Future<void> _contactarWhatsApp(String telefono) async {
    final mensaje = Uri.encodeComponent(
        'Hola, vi tu tarjeta en Puelo y quería hacerte una consulta.');
    final url = Uri.parse('https://wa.me/$telefono?text=$mensaje');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escenario de error: Sin referencia provista
    if (widget.usuarioRef == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildSimpleAppBar(),
        body: _buildStateMessage(
          icon: Icons.error_outline_rounded,
          title: 'Falta información',
          message: 'No se ha podido localizar la referencia de esta tarjeta.',
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.usuarioRef!.snapshots() as Stream<DocumentSnapshot<Map<String, dynamic>>>,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: _buildSimpleAppBar(),
            body: _buildStateMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Error de carga',
              message: 'Ocurrió un inconveniente al conectar con la base de datos.',
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: _buildSimpleAppBar(),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                strokeWidth: 3,
              ),
            ),
          );
        }

        // Extracción limpia de datos
        final datos = snapshot.data!.data() ?? {};
        final nombreComercial = datos['nombre_comercial'] ?? 'Sin Nombre Comercial';
        final nombre = datos['nombre'] ?? '';
        final apellido = datos['apellido'] ?? '';
        final telefono = datos['telefono'] ?? '';
        
        final List<dynamic> oficios = datos['profesiones'] ?? [];
        final List<dynamic> zonas = datos['zonas'] ?? [];

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: textColor,
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Tarjeta de Presentación',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: false,
            ),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cabecera: Avatar Dinámico Grande
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, primaryColor.withOpacity(0.75)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (nombre.isNotEmpty && apellido.isNotEmpty)
                                    ? '${nombre[0]}${apellido[0]}'.toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),

                        // Nombre de Fantasía o Comercial
                        Text(
                          nombreComercial,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Titular de la Credencial
                        Text(
                          '$nombre $apellido',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                        const SizedBox(height: 16.0),

                        // Sección: Oficios y Profesiones
                        if (oficios.isNotEmpty) ...[
                          _buildCardSectionHeader('Especialidad'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: oficios.map((oficio) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  oficio.toString(),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Sección: Zonas
                        if (zonas.isNotEmpty) ...[
                          _buildCardSectionHeader('Zonas de Atención'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: zonas.map((zona) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  zona.toString(),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 36),
                        ],

                        // Botón de contacto directo por WhatsApp (Efecto canónico)
                        ElevatedButton.icon(
                          onPressed: () => _contactarWhatsApp(telefono),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                          label: const Text(
                            'Consultar por WhatsApp',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366), 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18.0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            shadowColor: const Color(0xFF25D366).withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Header de subsecciones en la tarjeta
  Widget _buildCardSectionHeader(String title) {
    return Center(
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: subtitleColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // App Bar genérico de contingencia
  PreferredSizeWidget _buildSimpleAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: textColor,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // Mensaje de estado decorativo
  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: subtitleColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: subtitleColor, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
