import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Firma sonora PROX (2 sonidos core).
///
/// 1) [playOpen] / [playOpenOnce] — ingreso (primer gesto del usuario)
/// 2) [playConfirm] — envío exitoso (calificación, recibo)
///
/// Web: path same-origin `/content/brand/...` (Hosting).
/// Native: URL absoluta del Hosting.
class ProxSounds {
  ProxSounds._();

  static const String _hostBase =
      'https://lifewalletpuelo.web.app/content/brand';
  static const String _relativeBase = '/content/brand';

  static String get openUrl =>
      kIsWeb ? '$_relativeBase/prox_open.mp3' : '$_hostBase/prox_open.mp3';

  static String get confirmUrl => kIsWeb
      ? '$_relativeBase/prox_confirm.mp3'
      : '$_hostBase/prox_confirm.mp3';

  static AudioPlayer? _player;
  static bool _openPlayed = false;

  static AudioPlayer get _p {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Firma de marca (puede repetirse si se llama de nuevo).
  static Future<void> playOpen() => _play(openUrl, volume: 0.85);

  /// Firma de ingreso una sola vez por sesión de app (primer gesto).
  static Future<void> playOpenOnce() async {
    if (_openPlayed) return;
    _openPlayed = true;
    await playOpen();
  }

  /// Confirmación (calificación enviada, recibo emitido).
  static Future<void> playConfirm() => _play(confirmUrl, volume: 0.75);

  static Future<void> _play(String url, {double volume = 0.8}) async {
    try {
      await _p.stop();
      await _p.setVolume(volume.clamp(0.0, 1.0));
      await _p.play(UrlSource(url));
    } catch (e) {
      debugPrint('ProxSounds: $e');
      // Fallback absoluto si el path relative falló en web.
      if (kIsWeb && url.startsWith('/')) {
        try {
          final abs = '$_hostBase/${url.split('/').last}';
          await _p.play(UrlSource(abs));
        } catch (e2) {
          debugPrint('ProxSounds fallback: $e2');
        }
      }
    }
  }

  static Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
