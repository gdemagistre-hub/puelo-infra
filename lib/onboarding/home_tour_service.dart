import 'package:shared_preferences/shared_preferences.dart';

/// Marca si el usuario ya vio el tour de Home (por rol).
class HomeTourService {
  HomeTourService._();
  static final HomeTourService instance = HomeTourService._();

  static const _v = 'v1';
  static String _key(bool prestador) =>
      'puelo_home_tour_${_v}_${prestador ? 'prestador' : 'cliente'}';

  Future<bool> shouldShow({required bool modoPrestador}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_key(modoPrestador)) ?? false);
    } catch (_) {
      return false;
    }
  }

  Future<void> markDone({required bool modoPrestador}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(modoPrestador), true);
    } catch (_) {}
  }

  /// Para pruebas / menú de ayuda: volver a mostrar.
  Future<void> reset({required bool modoPrestador}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(modoPrestador));
    } catch (_) {}
  }

  Future<void> resetAll() async {
    await reset(modoPrestador: true);
    await reset(modoPrestador: false);
  }
}
