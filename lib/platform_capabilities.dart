import 'package:flutter/foundation.dart';

/// Capacidades por plataforma (mobile vs desktop/web).
/// Sprint 2: evita crashes al invocar cámara/OCR fuera de Android/iOS.
class PlatformCapabilities {
  PlatformCapabilities._();

  static bool get isMobileNative {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool get isDesktopNative {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Cámara nativa estable solo en mobile.
  static bool get supportsCamera => isMobileNative;

  /// Galería / file picker: web y mobile; desktop vía image_picker puede variar.
  static bool get supportsGallery => true;

  static bool get supportsOcr => isMobileNative;

  static String get cameraUnsupportedMessage =>
      'La cámara no está disponible en esta plataforma. '
      'Usá la galería o abrí la app en Android/iOS.';

  static String get ocrUnsupportedMessage =>
      'El escaneo OCR de DNI está disponible en Android e iOS.';
}
