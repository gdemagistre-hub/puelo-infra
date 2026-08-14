import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/leccion.dart';

class LeccionDetalleScreen extends StatefulWidget {
  const LeccionDetalleScreen({super.key, required this.leccion});

  final Leccion leccion;

  @override
  State<LeccionDetalleScreen> createState() => _LeccionDetalleScreenState();
}

class _LeccionDetalleScreenState extends State<LeccionDetalleScreen> {
  static const Color _primary = Color(0xFF28B5CD);
  static const Color _secondary = Color(0xFF734BE4);
  static const Color _text = Color(0xFF3D4756);
  static const Color _muted = Color(0xFF6B7280);

  final _player = AudioPlayer();
  bool _playing = false;
  bool _loadingAudio = false;
  String? _audioError;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final url = widget.leccion.audioUrl;
    if (url == null || url.isEmpty) return;

    setState(() {
      _audioError = null;
      _loadingAudio = true;
    });

    try {
      if (_playing) {
        await _player.stop();
        if (!mounted) return;
        setState(() {
          _playing = false;
          _loadingAudio = false;
        });
        return;
      }

      await _player.play(UrlSource(url));
      if (!mounted) return;
      setState(() {
        _playing = true;
        _loadingAudio = false;
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAudio = false;
        _playing = false;
        _audioError =
            'No se pudo reproducir el audio. Probá de nuevo en unos minutos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final leccion = widget.leccion;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          leccion.tag,
          style: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: _primary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Text(
            leccion.titulo,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _text,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: _muted),
              const SizedBox(width: 4),
              Text(
                '${leccion.minutos} min de lectura',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (leccion.hasAudio)
            Material(
              color: _secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _loadingAudio ? null : _toggleAudio,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      if (_loadingAudio)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          _playing
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                          color: _secondary,
                          size: 28,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _playing
                              ? 'Reproduciendo… tocá para detener'
                              : 'Escuchar en el viaje a la obra',
                          style: const TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.headphones_outlined, color: _secondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Audio: cuando esté disponible el MP3 de esta cápsula, va a aparecer acá.',
                      style: TextStyle(color: _text, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (_audioError != null) ...[
            const SizedBox(height: 8),
            Text(
              _audioError!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            leccion.cuerpo.trim(),
            style: const TextStyle(
              fontSize: 16,
              height: 1.55,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }
}
