import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Homepage.dart';
import 'scoring_service.dart';
import 'theme/app_colors.dart';
import 'user_session.dart';
import 'contacto_service.dart';

class TarjetaDigitalWidget extends StatefulWidget {
  const TarjetaDigitalWidget({super.key, this.usuarioRef});
  final DocumentReference? usuarioRef;
  static const String routeName = 'tarjetaDigital';
  static const String routePath = '/tarjetaDigital';
  @override
  State<TarjetaDigitalWidget> createState() => _TarjetaDigitalWidgetState();
}

class _TarjetaDigitalWidgetState extends State<TarjetaDigitalWidget> {
  DocumentReference? _resolvedRef;
  bool _loading = true;
  static const Color primaryColor = AppColors.prestador;
  static const Color accentColor = Color(0xFFE6F7FA);
  static const Color textColor = AppColors.text;
  static const Map<String, String> _labelOficio = {
    'electricidad': 'Electricista', 'plomeria': 'Plomería', 'gasista': 'Gasista',
    'carpinteria': 'Carpintería', 'pintura': 'Pintura', 'albanileria': 'Construcción',
    'jardineria': 'Jardinería', 'limpieza': 'Limpieza',
  };
  String _labelProf(dynamic p) {
    final k = p.toString().toLowerCase().trim();
    return _labelOficio[k] ?? p.toString();
  }

  @override
  void initState() {
    super.initState();
    if (widget.usuarioRef != null) {
      _resolvedRef = widget.usuarioRef;
      _loading = false;
    } else {
      try {
        final uri = Uri.base;
        String? id = uri.queryParameters['id'];
        if (id == null || id.isEmpty) {
          final fragment = uri.fragment;
          if (fragment.contains('?')) {
            id = Uri.parse(fragment).queryParameters['id'];
          }
        }
        if (id != null && id.isNotEmpty) {
          _resolvedRef = FirebaseFirestore.instance.collection('usuarios').doc(id);
        }
      } catch (e) {
        debugPrint('URL parse: $e');
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _contactarWhatsApp(String telefono, String nombre, {required String prestadorUid}) async {
    ContactoService.registrar(prestadorUid: prestadorUid, tipo: 'whatsapp', origen: 'tarjeta', prestadorNombre: nombre.isEmpty ? null : nombre);
    final tel = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent('Hola $nombre, vi tu tarjeta en Puelo y me gustaría hacerte una consulta.')}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    else _alerta('No se pudo abrir WhatsApp');
  }

  Future<void> _realizarLlamada(String telefono, {required String prestadorUid, String? prestadorNombre}) async {
    ContactoService.registrar(prestadorUid: prestadorUid, tipo: 'llamada', origen: 'tarjeta', prestadorNombre: prestadorNombre);
    final url = Uri.parse('tel:${telefono.replaceAll(RegExp(r'[^\d+]'), '')}');
    if (await canLaunchUrl(url)) await launchUrl(url);
    else _alerta('No se pudo iniciar la llamada');
  }

  Future<void> _compartirPorWhatsApp(String nombre, String idDocumento) async {
    final link = 'https://lifewalletpuelo.web.app/#/tarjetaDigital?id=$idDocumento';
    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent('¡Hola! Te comparto mi tarjeta de servicios en Puelo:\n\n$link')}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    else _alerta('No se pudo abrir WhatsApp para compartir');
  }

  void _copiarEnlace(String idDocumento) {
    Clipboard.setData(ClipboardData(text: 'https://lifewalletpuelo.web.app/#/tarjetaDigital?id=$idDocumento'));
    _alerta('¡Enlace copiado al portapapeles!');
  }

  void _alerta(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  void _onBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomePageWidget(initialModoPrestador: false)), (_) => false);
    }
  }

  Future<List<_FotoItem>> _cargarFotos(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('trabajos').where('trabajador_uid', isEqualTo: userId).where('tipo', isEqualTo: 'portfolio').limit(12).get();
      final items = <_FotoItem>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final url = (d['url_foto'] ?? d['foto_url'] ?? d['url'] ?? '').toString();
        if (url.isEmpty) continue;
        items.add(_FotoItem(url: url, desc: (d['descripcion'] ?? d['titulo'] ?? '').toString()));
      }
      if (items.isNotEmpty) return items;
    } catch (_) {}
    try {
      final snap = await FirebaseFirestore.instance.collection('trabajos').where('trabajador_uid', isEqualTo: userId).limit(12).get();
      final items = <_FotoItem>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final url = (d['url_foto'] ?? d['foto_url'] ?? d['url'] ?? '').toString();
        if (url.isEmpty) continue;
        items.add(_FotoItem(url: url, desc: (d['descripcion'] ?? d['titulo'] ?? '').toString()));
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: primaryColor)));
    if (_resolvedRef == null) {
      return Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: _onBack)), body: const Center(child: Text('No se encontró el perfil')));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: _resolvedRef!.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: primaryColor)));
        }
        final datos = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final nombre = (datos['nombre'] ?? '').toString();
        final apellido = (datos['apellido'] ?? '').toString();
        final comercial = (datos['nombre_comercial'] ?? '').toString().trim();
        final nombreMostrar = comercial.isNotEmpty ? comercial : '$nombre $apellido'.trim();
        final telefono = (datos['telefono'] ?? datos['celular'] ?? '').toString();
        final profesiones = datos['profesiones'] as List? ?? [];
        final docId = snapshot.data!.id;
        final esPropietario = UserSession().uid == docId;
        final badge = datos['badge_prestador'] as String?;
        final scoringMap = datos['scoring'];
        final nivelConfianza = scoringMap is Map ? scoringMap['nivel_confianza'] as String? : null;
        final scoreIdentidad = scoringMap is Map ? (scoringMap['score_identidad'] as num?)?.toInt() : null;
        final urlFoto = (datos['url_foto_perfil'] ?? datos['foto_perfil'])?.toString();
        final zonasMap = datos['zonas_cobertura'];
        List<String> zonasLista = [];
        if (zonasMap is Map && zonasMap['localidades'] is List) {
          for (final e in (zonasMap['localidades'] as List)) {
            if (e is Map) {
              final n = (e['nombre'] ?? e['localidad_nombre'] ?? '').toString();
              if (n.isNotEmpty) zonasLista.add(n);
            }
          }
        }
        final promedio = (datos['promedioEstrellas'] as num?)?.toDouble() ?? 0.0;
        final cantEval = (datos['cantidadEvaluadores'] as num?)?.toInt() ?? 0;
        final initials = () {
          final n = nombre.trim(); final a = apellido.trim();
          if (n.isEmpty && a.isEmpty) return 'P';
          if (a.isEmpty) return n[0].toUpperCase();
          if (n.isEmpty) return a[0].toUpperCase();
          return '${n[0]}${a[0]}'.toUpperCase();
        }();

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), color: textColor, onPressed: _onBack),
            title: const Text('Tarjeta digital', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (esPropietario) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: primaryColor.withOpacity(0.2))),
                  child: Column(children: [
                    Text('Compartila con clientes nuevos por WhatsApp.', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(onPressed: () => _compartirPorWhatsApp(nombreMostrar, docId), icon: const FaIcon(FontAwesomeIcons.whatsapp, color: AppColors.whatsapp)),
                      IconButton(onPressed: () => _copiarEnlace(docId), icon: Icon(Icons.link_rounded, color: primaryColor)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Column(children: [
                  CircleAvatar(
                    radius: 48, backgroundColor: primaryColor.withOpacity(0.15),
                    backgroundImage: (urlFoto != null && urlFoto.isNotEmpty) ? NetworkImage(urlFoto) : null,
                    child: (urlFoto == null || urlFoto.isEmpty) ? Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)) : null,
                  ),
                  const SizedBox(height: 14),
                  Text(nombreMostrar.isEmpty ? 'Prestador' : nombreMostrar, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor), textAlign: TextAlign.center),
                  if (profesiones.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: profesiones.take(6).map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(_labelProf(p), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor)),
                    )).toList()),
                  ],
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (badge != null && badge.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFDBA74))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFFEA580C)),
                          const SizedBox(width: 4),
                          Text(ScoringService.labelBadge(badge), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC2410C))),
                        ]),
                      ),
                    if (cantEval > 0) Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFB000), size: 18),
                      Text(' ${promedio.toStringAsFixed(1)} ($cantEval)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textColor)),
                    ]),
                  ]),
                  if (nivelConfianza != null || scoreIdentidad != null) ...[
                    const SizedBox(height: 10),
                    Text([if (nivelConfianza != null) ScoringService.labelNivel(nivelConfianza), if (scoreIdentidad != null) '$scoreIdentidad/100'].join(' · '), style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  ],
                  if (zonasLista.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Flexible(child: Text(zonasLista.take(3).join(', '), style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              if (telefono.trim().isNotEmpty)
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _contactarWhatsApp(telefono, nombre.isEmpty ? nombreMostrar : nombre, prestadorUid: docId),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsapp, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                    label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => _realizarLlamada(telefono, prestadorUid: docId, prestadorNombre: nombreMostrar),
                    style: OutlinedButton.styleFrom(foregroundColor: primaryColor, side: const BorderSide(color: primaryColor), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Llamar', style: TextStyle(fontWeight: FontWeight.w700)),
                  )),
                ]),
              const SizedBox(height: 24),
              FutureBuilder<List<_FotoItem>>(
                future: _cargarFotos(docId),
                builder: (context, snap) {
                  final items = snap.data ?? [];
                  final loading = snap.connectionState == ConnectionState.waiting;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('Trabajos realizados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
                      const Spacer(),
                      if (!loading && items.isNotEmpty)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(6)),
                          child: Text('${items.length} FOTO${items.length == 1 ? '' : 'S'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: primaryColor))),
                    ]),
                    const SizedBox(height: 12),
                    if (loading)
                      const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2)))
                    else if (items.isEmpty)
                      Container(width: double.infinity, padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Text(esPropietario ? 'Subí fotos de trabajos hechos para que el cliente vea tu experiencia.' : 'Este prestador aún no subió fotos de trabajos.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)))
                    else
                      GridView.builder(
                        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_outlined, color: Colors.grey))));
                        },
                      ),
                  ]);
                },
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _FotoItem {
  final String url;
  final String desc;
  _FotoItem({required this.url, required this.desc});
}
