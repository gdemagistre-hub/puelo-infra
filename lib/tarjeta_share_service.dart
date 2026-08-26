import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Crea o reutiliza el link temporal de la tarjeta (21 días).
class TarjetaShareService {
  TarjetaShareService._();

  static const String functionsRegion = 'us-east1';

  static Future<String> crearEnlace({bool rotar = false}) async {
    final fn = FirebaseFunctions.instanceFor(region: functionsRegion);
    final result = await fn.httpsCallable('crearTarjetaShare').call({
      'rotar': rotar,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final url = (data['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw StateError('La función no devolvió url');
    }
    debugPrint('TarjetaShareService url=$url');
    return url;
  }
}
