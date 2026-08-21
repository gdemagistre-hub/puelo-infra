import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Firma sonora PROX (2 sonidos core).
///
/// 1) [playOpen] — splash / ingreso (~2.4s)
/// 2) [playConfirm] — envío exitoso (calificación, recibo)
///
/// Fuente: same-origin Hosting `content/brand/` (CI copia el repo).
/// Fallback opcional: `assets/sounds/` si está empaquetado.
class ProxSounds {
  ProxSounds._();

  static const String _base =
      'https://lifewalletpuelo.web.app/content/brand';

  static const String openUrl = '$_base/prox_open.mp3';
  static const String confirmUrl = '$_base/prox_confirm.mp3';

  static AudioPlayer? _player;

  static AudioPlayer get _p {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Firma de marca al abrir la app.
  static Future<void> playOpen() => _play(openUrl, volume: 0.85);

  /// Confirmación (calificación enviada, recibo emitido).
  static Future<void> playConfirm() => _play(confirmUrl, volume: 0.75);

  static Future<void> _play(String url, {double volume = 0.8}) async {
    try {
      await _p.stop();
      await _p.setVolume(volume.clamp(0.0, 1.0));
      await _p.play(UrlSource(url));
    } catch (e) {
      debugPrint('ProxSounds: $e');
    }
  }

  static Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
