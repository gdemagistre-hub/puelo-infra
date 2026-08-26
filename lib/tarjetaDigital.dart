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
import 'contacto/post_contacto_sheet.dart';
import 'mensajes/emitir_recibo_sheet.dart';
import 'tarjeta_share_service.dart';

/// Tarjeta UX v2 — mismo diseño para cliente y prestador (hero trust).
class TarjetaDigitalWidget extends StatefulWidget {
  const TarjetaDigitalWidget({super.key, this.usuarioRef, this.shareToken});
  final DocumentReference? usuarioRef;
  final String? shareToken;
  static const String routeName = 'tarjetaDigital';
  static const String routePath = '/tarjetaDigital';
  @override
  State<TarjetaDigitalWidget> createState() => _TarjetaDigitalWidgetState();
}

class _TarjetaDigitalWidgetState extends State<TarjetaDigitalWidget> {
  DocumentReference? _resolvedRef;
  bool _loading = true;
  Future<List<_FotoItem>>? _fotosFuture;

  static const Color primaryColor = AppColors.prestador;
  static const Color primaryDark = Color(0xFF1A8FA3);
  static const Color accentColor = Color(0xFFE6F7FA);
  static const Color textColor = AppColors.text;
  static const Color bgColor = Color(0xFFF1F5F9);

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
    final tok = (widget.shareToken ?? '').trim();
    if (tok.isNotEmpty) {
      _resolvedRef = FirebaseFirestore.instance.collection('tarjetas_share').doc(tok);
      _fotosFuture = FirebaseFirestore.instance.collection('tarjetas_share').doc(tok).get().then((s) {
        final uid = (s.data()?['prestador_uid'] ?? '').toString().trim();
        if (uid.isEmpty) return <_FotoItem>[];
        return _cargarFotos(uid);
      });
      _loading = false;
      return;
    }
    if (widget.usuarioRef != null) {
      _resolvedRef = widget.usuarioRef;
      _fotosFuture = _cargarFotos(_resolvedRef!.id);
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
          _fotosFuture = _cargarFotos(id);
        }
      } catch (e) {
        debugPrint('URL parse: $e');
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _contactarWhatsApp(String telefono, String nombre, {required String prestadorUid}) async {
    if ((telefono).trim().isEmpty) {
      final got = await ContactoService.resolverTelefono(prestadorUid: prestadorUid, tipo: 'whatsapp', origen: 'tarjeta', prestadorNombre: nombre);
      if (got == null || got.isEmpty) {
        _alerta(UserSession().uid == null ? 'Entrá con tu cuenta para escribirle por WhatsApp' : 'No hay WhatsApp disponible');
        return;
      }
      telefono = got;
    }
    ContactoService.registrar(prestadorUid: prestadorUid, tipo: 'whatsapp', origen: 'tarjeta', prestadorNombre: nombre.isEmpty ? null : nombre);
    final tel = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent('Hola $nombre, vi tu tarjeta en Puelo y me gustaría hacerte una consulta.')}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    else _alerta('No se pudo abrir WhatsApp');
    if (!mounted) return;
    await PostContactoSheet.show(
      context,
      prestadorUid: prestadorUid,
      prestadorNombre: nombre.isEmpty ? null : nombre,
      desdeTarjeta: true,
      onPrimary: () => _emitirRecibo(prestadorUid, nombre),
    );
  }

  Future<void> _realizarLlamada(String telefono, {required String prestadorUid, String? prestadorNombre}) async {
    if ((telefono).trim().isEmpty) {
      final got = await ContactoService.resolverTelefono(prestadorUid: prestadorUid, tipo: 'llamada', origen: 'tarjeta', prestadorNombre: prestadorNombre);
      if (got == null || got.isEmpty) {
        _alerta(UserSession().uid == null ? 'Entrá con tu cuenta para llamarlo' : 'No hay teléfono disponible');
        return;
      }
      telefono = got;
    }
    ContactoService.registrar(prestadorUid: prestadorUid, tipo: 'llamada', origen: 'tarjeta', prestadorNombre: prestadorNombre);
    final url = Uri.parse('tel:${telefono.replaceAll(RegExp(r'[^\d+]'), '')}');
    if (await canLaunchUrl(url)) await launchUrl(url);
    else _alerta('No se pudo iniciar la llamada');
    if (!mounted) return;
    await PostContactoSheet.show(
      context,
      prestadorUid: prestadorUid,
      prestadorNombre: prestadorNombre,
      desdeTarjeta: true,
      onPrimary: () => _emitirRecibo(prestadorUid, prestadorNombre ?? ''),
    );
  }

  Future<void> _compartirPorWhatsApp(String nombre, String idDocumento) async {
    final linkShare = await TarjetaShareService.crearEnlace();
    final origin = linkShare;
    final link = origin;
    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent('¡Hola! Te comparto mi tarjeta de servicios en Puelo:\n\n$link')}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    else _alerta('No se pudo abrir WhatsApp para compartir');
  }

  Future<void> _copiarEnlace(String idDocumento) async {
    final link = await TarjetaShareService.crearEnlace();
    await Clipboard.setData(ClipboardData(text: link));
    _alerta('¡Enlace copiado al portapapeles!');
  }

  void _emitirRecibo(String contraparteUid, String nombreMostrar) {
    final my = UserSession().uid;
    if (my == null || my.isEmpty) {
      _alerta('Entrá con Google (no el menú de prueba) para registrar un pago');
      return;
    }
    if (my == contraparteUid) {
      _alerta('No podés registrar un pago a vos mismo');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EmitirReciboSheet(
        contraparteUidFijo: contraparteUid,
        contraparteNombre: nombreMostrar.isEmpty ? null : nombreMostrar,
      ),
    );
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
    final items = <_FotoItem>[];
    final seen = <String>{};
    void extraerDeDoc(Map<String, dynamic> d) {
      final imgs = d['imagenes'] as List? ?? d['fotos'] as List? ?? [];
      for (final img in imgs) {
        String? url; String desc = '';
        if (img is String) url = img;
        else if (img is Map) { url = (img['url'] ?? img['downloadURL'] ?? img['src'] ?? '').toString(); desc = (img['descripcion'] ?? img['caption'] ?? '').toString(); }
        if (url != null && url.isNotEmpty && seen.add(url)) items.add(_FotoItem(url: url, desc: desc));
      }
    }
    bool coincide(Map<String, dynamic> d) {
      final uid = (d['usuario_id'] ?? d['uid'] ?? '').toString();
      if (uid == userId) return true;
      final ref = d['trabajadorRef'];
      if (ref is DocumentReference && ref.id == userId) return true;
      if (ref is String && (ref.endsWith('/$userId') || ref == userId)) return true;
      return false;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('trabajos').where('usuario_id', isEqualTo: userId).limit(40).get();
      for (final doc in snap.docs) {
        final d = doc.data(); final tipo = (d['tipo'] ?? '').toString().toLowerCase();
        if (tipo.isEmpty || tipo == 'portfolio' || tipo == 'trabajo') extraerDeDoc(d);
      }
    } catch (e) { debugPrint('fotos query usuario_id: $e'); }
    if (items.isNotEmpty) return items;
    try {
      final ref = FirebaseFirestore.instance.collection('usuarios').doc(userId);
      final snap = await FirebaseFirestore.instance.collection('trabajos').where('trabajadorRef', isEqualTo: ref).limit(40).get();
      for (final doc in snap.docs) extraerDeDoc(doc.data());
    } catch (e) { debugPrint('fotos query trabajadorRef: $e'); }
    if (items.isNotEmpty) return items;
    try {
      final snap = await FirebaseFirestore.instance.collection('trabajos').limit(120).get();
      for (final doc in snap.docs) { final d = doc.data(); if (coincide(d)) extraerDeDoc(d); }
    } catch (e) { debugPrint('fotos fallback scan: $e'); }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: bgColor, body: Center(child: CircularProgressIndicator(color: primaryColor)));
    if (_resolvedRef == null) {
      return Scaffold(backgroundColor: bgColor, appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: _onBack)), body: const Center(child: Text('No se encontró el perfil')));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: _resolvedRef!.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(backgroundColor: bgColor, body: Center(child: CircularProgressIndicator(color: primaryColor)));
        }
        final datos = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final nombre = (datos['nombre'] ?? '').toString();
        final apellido = (datos['apellido'] ?? '').toString();
        final comercial = (datos['nombre_comercial'] ?? '').toString().trim();
        final nombreMostrar = comercial.isNotEmpty ? comercial : '$nombre $apellido'.trim();
        final telefono = (datos['telefono'] ?? datos['celular'] ?? '').toString();
        final profesiones = datos['profesiones'] as List? ?? [];
        final rawId = snapshot.data!.id;
        final docId = (datos['prestador_uid'] ?? '').toString().trim().isNotEmpty ? (datos['prestador_uid'] as String).trim() : rawId;
        final esPropietario = UserSession().uid == docId;
        final badge = (datos['list_badge'] ?? datos['badge_prestador'])?.toString();
        final scoringMap = datos['scoring'];
        final scoreRaw = datos['list_score_identidad'] ?? (scoringMap is Map ? scoringMap['score_identidad'] : null);
        final scoreIdentidad = scoreRaw is num ? scoreRaw.toInt() : 0;
        final scoreClamped = scoreIdentidad.clamp(0, 100);
        final scoreProgress = scoreClamped / 100.0;
        final urlFoto = (datos['url_foto_perfil'] ?? datos['foto_perfil'])?.toString();
        final zonasMap = datos['zonas_cobertura'];
        final zonasLista = <String>[];
        if (zonasMap is Map && zonasMap['localidades'] is List) {
          for (final e in (zonasMap['localidades'] as List)) {
            if (e is Map) { final n = (e['nombre'] ?? e['localidad_nombre'] ?? '').toString(); if (n.isNotEmpty) zonasLista.add(n); }
          }
        }
        final starsRaw = datos['list_promedio'] ?? datos['promedioEstrellas'] ?? 0;
        final promedio = starsRaw is num ? starsRaw.toDouble() : (double.tryParse('$starsRaw') ?? 0.0);
        final nRaw = datos['list_n_evaluaciones'] ?? datos['nEvaluaciones'] ?? datos['cantidad_evaluaciones'] ?? datos['cantidadEvaluadores'] ?? 0;
        final cantEval = nRaw is num ? nRaw.toInt() : (int.tryParse('$nRaw') ?? 0);
        final badgeLabel = (badge != null && badge.isNotEmpty) ? ScoringService.labelBadge(badge) : '';
        final badgeColors = ScoringService.coloresBadge((badge != null && badge.isNotEmpty) ? badge : null);
        String microcopy;
        if (cantEval > 0 && promedio > 0) microcopy = 'Los clientes lo califican con ${promedio.toStringAsFixed(1)}';
        else if (scoreClamped > 0) microcopy = 'Perfil en Puelo · confianza $scoreClamped/100';
        else microcopy = 'Perfil en Puelo · todavía sin reseñas de trabajos';
        final initials = () {
          final n = nombre.trim(); final a = apellido.trim();
          if (n.isEmpty && a.isEmpty) return 'P';
          if (a.isEmpty) return n[0].toUpperCase();
          if (n.isEmpty) return a[0].toUpperCase();
          return '${n[0]}${a[0]}'.toUpperCase();
        }();
        final hasTel = ContactoService.puedeContactar(datos) || telefono.trim().isNotEmpty || (datos['prestador_uid'] ?? '').toString().trim().isNotEmpty;

        return Scaffold(
          backgroundColor: bgColor,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [primaryColor, primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                          child: Row(children: [
                            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: _onBack),
                            const Expanded(child: Text('Tarjeta digital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6))],
                            color: Colors.white,
                            image: (urlFoto != null && urlFoto.isNotEmpty) ? DecorationImage(image: NetworkImage(urlFoto), fit: BoxFit.cover) : null,
                          ),
                          alignment: Alignment.center,
                          child: (urlFoto == null || urlFoto.isEmpty) ? Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primaryColor)) : null,
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(nombreMostrar.isEmpty ? 'Prestador' : nombreMostrar, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4, height: 1.15)),
                        ),
                        if (profesiones.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Wrap(
                              spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
                              children: profesiones.take(6).map((p) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.35))),
                                child: Text(_labelProf(p), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                              )).toList(),
                            ),
                          ),
                        ],
                        if (zonasLista.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.location_on_outlined, size: 16, color: Colors.white.withOpacity(0.9)),
                              const SizedBox(width: 4),
                              Flexible(child: Text('Trabaja en ${zonasLista.take(3).join(', ')}', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500))),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      elevation: 8,
                      shadowColor: primaryColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.12))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Así lo ven otros clientes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(child: _metricTile(child: Column(children: [
                                if (badgeLabel.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: Color(badgeColors.background), borderRadius: BorderRadius.circular(20), border: Border.all(color: Color(badgeColors.foreground).withOpacity(0.35))),
                                    child: Text(badgeLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(badgeColors.foreground))),
                                  )
                                else Text('Sin nivel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                                const SizedBox(height: 4),
                                Text('Nivel', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ]))),
                              const SizedBox(width: 8),
                              Expanded(child: _metricTile(child: Column(children: [
                                SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
                                  SizedBox(width: 44, height: 44, child: CircularProgressIndicator(value: scoreIdentidad > 0 ? scoreProgress : 0, strokeWidth: 5, backgroundColor: const Color(0xFFE2E8F0), color: const Color(0xFF16A34A), strokeCap: StrokeCap.round)),
                                  Text(scoreIdentidad > 0 ? '$scoreClamped' : '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                ])),
                                const SizedBox(height: 4),
                                Text(scoreIdentidad > 0 ? '$scoreClamped/100' : 'Confianza', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ]))),
                              const SizedBox(width: 8),
                              Expanded(child: _metricTile(child: Column(children: [
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 18),
                                  const SizedBox(width: 4),
                                  Text(cantEval > 0 ? promedio.toStringAsFixed(1) : '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                ]),
                                const SizedBox(height: 4),
                                Text(cantEval > 0 ? '($cantEval eval)' : 'Sin eval.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ]))),
                            ]),
                            const SizedBox(height: 12),
                            Text(microcopy, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(children: [
                    Expanded(flex: 3, child: SizedBox(height: 52, child: ElevatedButton.icon(
                      onPressed: hasTel ? () => _contactarWhatsApp(telefono, nombreMostrar.isEmpty ? nombre : nombreMostrar, prestadorUid: docId) : null,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ))),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: SizedBox(height: 52, child: OutlinedButton.icon(
                      onPressed: hasTel ? () => _realizarLlamada(telefono, prestadorUid: docId, prestadorNombre: nombreMostrar.isEmpty ? null : nombreMostrar) : null,
                      style: OutlinedButton.styleFrom(foregroundColor: primaryColor, side: BorderSide(color: primaryColor.withOpacity(0.55), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      icon: const Icon(Icons.phone_outlined, size: 20),
                      label: const Text('Llamar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ))),
                  ]),
                ),
              ),
              if (!esPropietario && (UserSession().uid != null && UserSession().uid!.isNotEmpty))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _emitirRecibo(
                          docId,
                          nombreMostrar.isEmpty ? '$nombre $apellido'.trim() : nombreMostrar,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor.withOpacity(0.45), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 20),
                        label: const Text(
                          'Doy un pago',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ),
              if (esPropietario)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Material(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Expanded(child: Text('Compartí tu tarjeta con clientes', style: TextStyle(color: primaryDark, fontWeight: FontWeight.w700, fontSize: 13))),
                          IconButton(onPressed: () => _compartirPorWhatsApp(nombreMostrar, docId), icon: const FaIcon(FontAwesomeIcons.whatsapp, color: AppColors.whatsapp, size: 20), tooltip: 'WhatsApp'),
                          IconButton(onPressed: () => _copiarEnlace(docId), icon: Icon(Icons.link_rounded, color: primaryColor, size: 22), tooltip: 'Copiar enlace'),
                        ]),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: FutureBuilder<List<_FotoItem>>(
                    future: _fotosFuture,
                    builder: (context, snap) {
                      final loading = snap.connectionState == ConnectionState.waiting;
                      final items = snap.data ?? [];
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                            child: Column(children: [
                              Icon(Icons.photo_library_outlined, size: 32, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(esPropietario ? 'Subí fotos de trabajos hechos para que el cliente vea tu experiencia.' : 'Aún no publicó fotos de trabajos.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.35)),
                              if (!esPropietario) ...[
                                const SizedBox(height: 12),
                                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                                  if (profesiones.isNotEmpty) _signalChip('Oficios cargados'),
                                  if (zonasLista.isNotEmpty) _signalChip('Zona definida'),
                                  if (scoreClamped > 0) _signalChip('Perfil en Puelo'),
                                ]),
                              ],
                            ]),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];
                              return ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(item.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_outlined, color: Colors.grey))));
                            },
                          ),
                      ]);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricTile({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: child,
    );
  }

  Widget _signalChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.25))),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryDark)),
    );
  }
}

class _FotoItem {
  final String url;
  final String desc;
  _FotoItem({required this.url, required this.desc});
}
