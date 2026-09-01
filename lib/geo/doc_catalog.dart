import '../user_session.dart';
import 'country_profile.dart';

/// Catálogo de documento / país emisor según [CountryProfile].
/// Sin BR. Sin pack OCR fuera de AR.
class DocCatalog {
  DocCatalog._();

  static CountryProfile get profile =>
      CountryProfile.of(UserSession().countryCode);

  static bool get ocrEnabled => profile.ocrDniEnabled;

  static List<String> tipos({String? current}) {
    final types = List<String>.from(profile.idTypes);
    final cur = (current ?? '').trim();
    if (cur.isNotEmpty && !types.contains(cur)) types.add(cur);
    return types;
  }

  static List<String> paisesEmisor({String? current}) {
    final names = List<String>.from(CountryProfile.supportedNames);
    names.add('Otro');
    final cur = (current ?? '').trim();
    if (cur.isNotEmpty && !names.contains(cur)) names.add(cur);
    return names;
  }
}
