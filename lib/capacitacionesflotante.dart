import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'user_session.dart';

/// Cursos, capacitaciones y constancias del prestador.
/// Solo evidencia visual + título. **No** alimenta scoring (evita incentivos a certificados falsos).
class CapacitacionesFlotanteWidget extends StatefulWidget {
  const CapacitacionesFlotanteWidget({super.key});

  static const int maxItems = 6;

  @override
  State<CapacitacionesFlotanteWidget> createState() =>
      _CapacitacionesFlotanteWidgetState();
}

class _CapacitacionesFlotanteWidgetState
    extends State<CapacitacionesFlotanteWidget> {
  static const Color primaryColor = Color(0xFF28B5CD);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF1E293B);

  final db = FirebaseFirestore.instance;
  List<_CapacitacionItem> _items = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await db.collection('usuarios').doc(uid).get();
      final raw = doc.data()?['capacitaciones'];
      final list = <_CapacitacionItem>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            list.add(_CapacitacionItem.fromMap(Map<String, dynamic>.from(e)));
          }
        }
      }
      list.sort((a, b) => b.orden.compareTo(a.orden));
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Capacitaciones cargar: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persistir(List<_CapacitacionItem> items) async {
    final uid = UserSession().uid;
    if (uid == null) return;
    final payload = items.map((e) => e.toMap()).toList();
    await db.collection('usuarios').doc(uid).set({
      'capacitaciones': payload,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final session = UserSession();
    if (session.datosCompletos != null) {
      session.datosCompletos = {
        ...session.datosCompletos!,
        'capacitaciones': payload,
      };
    }
    session.invalidateHomeCache();
  }

  Future<void> _agregar() async {
    if (_items.length >= CapacitacionesFlotanteWidget.maxItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Máximo ${CapacitacionesFlotanteWidget.maxItems} capacitaciones. '
            'Borrá una para sumar otra.',
          ),
        ),
      );
      return;
    }

    final tituloCtrl = TextEditingController();
    final anioCtrl = TextEditingController();
    Uint8List? bytes;
    String? previewHint;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const Text(
                    'Agregar capacitación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sacá una foto del certificado, matrícula o constancia '
                    'y escribí de qué se trata. No suma puntos de confianza: '
                    'solo se muestra en tu perfil.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: ctx,
                        builder: (c2) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_camera_outlined),
                                title: const Text('Tomar foto'),
                                onTap: () =>
                                    Navigator.pop(c2, ImageSource.camera),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library_outlined),
                                title: const Text('Elegir de galería'),
                                onTap: () =>
                                    Navigator.pop(c2, ImageSource.gallery),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (source == null) return;
                      final picker = ImagePicker();
                      final file = await picker.pickImage(
                        source: source,
                        maxWidth: 1200,
                        maxHeight: 1600,
                        imageQuality: 75,
                      );
                      if (file == null) return;
                      final b = await file.readAsBytes();
                      setModal(() {
                        bytes = b;
                        previewHint =
                            kIsWeb ? 'Imagen lista' : 'Foto lista para subir';
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: bytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    size: 36, color: primaryColor),
                                const SizedBox(height: 8),
                                Text(
                                  'Foto del certificado o constancia',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(
                                bytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 140,
                              ),
                            ),
                    ),
                  ),
                  if (previewHint != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      previewHint!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: tituloCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: '¿Qué es?',
                      hintText: 'Ej: Curso de soldadura TIG · 2024',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: anioCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Año (opcional)',
                      hintText: '2024',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () {
                        if (bytes == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Agregá una foto del documento'),
                            ),
                          );
                          return;
                        }
                        if (tituloCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Escribí de qué se trata'),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true || bytes == null) return;
    final titulo = tituloCtrl.text.trim();
    if (titulo.isEmpty) return;
    final anio = int.tryParse(anioCtrl.text.trim());

    final uid = UserSession().uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance
          .ref()
          .child('usuarios')
          .child(uid)
          .child('capacitaciones')
          .child('$id.jpg');
      final upload = await ref.putData(
        bytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await upload.ref.getDownloadURL();

      final item = _CapacitacionItem(
        id: id,
        titulo: titulo,
        urlFoto: url,
        anio: anio,
        orden: DateTime.now().millisecondsSinceEpoch,
      );
      final next = [item, ..._items];
      await _persistir(next);
      if (mounted) {
        setState(() {
          _items = next;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Capacitación agregada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Capacitaciones agregar: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    }
  }

  Future<void> _borrar(_CapacitacionItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar capacitación'),
        content: Text('¿Borrar "${item.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final next = _items.where((e) => e.id != item.id).toList();
      await _persistir(next);
      // Best-effort borrar foto en Storage
      final uid = UserSession().uid;
      if (uid != null) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child('usuarios')
              .child(uid)
              .child('capacitaciones')
              .child('${item.id}.jpg')
              .delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _items = next;
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _verFoto(String url, String titulo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(titulo, style: const TextStyle(fontSize: 14)),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No se pudo cargar la imagen',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: _textColor,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Preparación y cursos',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _agregar,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Agregar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryColor.withOpacity(0.25)),
                  ),
                  child: const Text(
                    'Mostrá cursos, matrículas o constancias. '
                    'El cliente puede verlos en tu perfil. '
                    'No modifican tu puntaje de confianza.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.school_outlined,
                            size: 40, color: primaryColor.withOpacity(0.7)),
                        const SizedBox(height: 12),
                        const Text(
                          'Todavía no cargaste capacitaciones',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tocá "Agregar" y subí una foto del certificado '
                          'con un título corto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._items.map((item) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        leading: GestureDetector(
                          onTap: () => _verFoto(item.urlFoto, item.titulo),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.urlFoto,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          item.titulo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: item.anio != null
                            ? Text(
                                '${item.anio}',
                                style: const TextStyle(fontSize: 12),
                              )
                            : const Text(
                                'Tocá la foto para ampliar',
                                style: TextStyle(fontSize: 12),
                              ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.grey.shade500,
                          onPressed: _saving ? null : () => _borrar(item),
                        ),
                        onTap: () => _verFoto(item.urlFoto, item.titulo),
                      ),
                    );
                  }),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CapacitacionItem {
  final String id;
  final String titulo;
  final String urlFoto;
  final int? anio;
  final int orden;

  _CapacitacionItem({
    required this.id,
    required this.titulo,
    required this.urlFoto,
    this.anio,
    required this.orden,
  });

  factory _CapacitacionItem.fromMap(Map<String, dynamic> m) {
    return _CapacitacionItem(
      id: (m['id'] ?? '').toString(),
      titulo: (m['titulo'] ?? '').toString(),
      urlFoto: (m['url_foto'] ?? '').toString(),
      anio: (m['anio'] as num?)?.toInt(),
      orden: (m['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'titulo': titulo,
        'url_foto': urlFoto,
        if (anio != null) 'anio': anio,
        'orden': orden,
      };
}
