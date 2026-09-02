import 'dart:convert';
import 'dart:typed_data';

/// Logo Prox splash (WebP + alpha). Recorte del adjunto transparente.
const String kProxSplashLogoB64 = 'PLACEHOLDER_TOO_LARGE';

final Uint8List kProxSplashLogoBytes =
    Uint8List.fromList(base64Decode(kProxSplashLogoB64));
