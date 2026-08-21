import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Firma sonora PROX (2 sonidos core).
///
/// 1) [playOpen] — splash / ingreso (~2.4s)
/// 2) [playConfirm] — envío exitoso (calificación, recibo)
///
/// Fuente primaria: same-origin Hosting `content/brand/` (CI copia el repo).
/// Fallback: asset local `assets/sounds/` si está empaquetado.
class ProxSounds {
  ProxSounds._();

  static const String _base =
      'https://lifewalletpuelo.web.app/content/brand';

  static const String openUrl = '$_base/prox_open.mp3';
  static const String confirmUrl = '$_base/prox_confirm.mp3';

  static const String openAsset = 'assets/sounds/prox_open.mp3';
  static const String confirmAsset = 'assets/sounds/prox_confirm.mp3';

  static AudioPlayer? _player;

  static AudioPlayer get _p {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Firma de marca al abrir la app.
  static Future<void> playOpen() => _play(
        url: openUrl,
        asset: openAsset,
        volume: 0.85,
      );

  /// Confirmación corta (calificación enviada, recibo emitido).
  static Future<void> playConfirm() => _play(
        url: confirmUrl,
        asset: confirmAsset,
        volume: 0.75,
      );

  static Future<void> _play({
    required String url,
    required String asset,
    double volume = 0.8,
  }) async {
    try {
      await _p.stop();
      await _p.setVolume(volume.clamp(0.0, 1.0));
      // Prefer asset offline; si falla, same-origin Hosting.
      try {
        await _p.play(AssetSource(asset.replaceFirst('assets/', '')));
        return;
      } catch (_) {
        // AssetSource path is relative to assets/ folder in pubspec.
      }
      try {
        await _p.play(AssetSource(asset));
        return;
      } catch (_) {}
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
