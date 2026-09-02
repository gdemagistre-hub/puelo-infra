import 'dart:convert';
import 'dart:typed_data';

import 'prox_splash_b64_a.dart';
import 'prox_splash_b64_b.dart';
import 'prox_splash_b64_c.dart';

/// Logo Prox splash (WebP lossless + alpha). Recorte del adjunto.
final Uint8List kProxSplashLogoBytes = Uint8List.fromList(
  base64Decode(
    (kProxSplashB64A + kProxSplashB64B + kProxSplashB64C).replaceAll('\n', ''),
  ),
);
