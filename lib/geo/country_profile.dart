/// Perfil de país (LATAM hispanohablante). Fallback AR.
/// No i18n. No ES. No BR. geoReady AR/CL/UY. OCR solo AR.
class CountryProfile {
  const CountryProfile({
    required this.iso,
    required this.name,
    required this.currency,
    required this.dialCode,
    required this.phoneExample,
    required this.phoneMin,
    required this.phoneMax,
    required this.geoReady,
    required this.idTypes,
    required this.ocrDniEnabled,
    required this.legalPack,
    required this.labelNivel1,
    required this.labelNivel2,
    required this.labelNivel3,
    required this.geoLevels,
  });

  final String iso;
  final String name;
  final String currency;
  final String dialCode;
  final String phoneExample;
  final int phoneMin;
  final int phoneMax;
  final bool geoReady;
  final List<String> idTypes;
  final bool ocrDniEnabled;
  final String legalPack;
  final String labelNivel1;
  final String labelNivel2;
  final String labelNivel3;
  /// 3 = región/provincia/comuna (o AR). 2 = departamento + localidad (UY).
  final int geoLevels;

  static const String defaultIso = 'AR';
  static const String defaultCurrency = 'ARS';

  /// Países que se pueden elegir hoy. El resto se muestra grisado.
  static const List<String> launchIsos = ['AR', 'CL', 'UY'];

  static const List<String> _latamEs = [
    'AR', 'UY', 'CL', 'PY', 'BO', 'PE', 'EC', 'CO', 'VE',
    'MX', 'GT', 'HN', 'SV', 'NI', 'CR', 'PA', 'DO', 'CU',
  ];

  static const List<String> _idAr = ['DNI', 'CUIT', 'Pasaporte', 'CI', 'Otro'];
  static const List<String> _idCl = ['RUT', 'Pasaporte', 'Otro'];
  static const List<String> _idUy = ['CI', 'Pasaporte', 'Otro'];
  static const List<String> _idMx = ['INE', 'CURP', 'Pasaporte', 'Otro'];
  static const List<String> _idGen = ['CI', 'Pasaporte', 'Otro'];

  static CountryProfile _row({
    required String iso,
    required String name,
    required String currency,
    required String dialCode,
    required String phoneExample,
    required int phoneMin,
    required int phoneMax,
    List<String>? idTypes,
    bool geoReady = false,
    bool ocrDniEnabled = false,
    String? legalPack,
    String? labelNivel1,
    String? labelNivel2,
    String? labelNivel3,
    int geoLevels = 3,
  }) {
    return CountryProfile(
      iso: iso,
      name: name,
      currency: currency,
      dialCode: dialCode,
      phoneExample: phoneExample,
      phoneMin: phoneMin,
      phoneMax: phoneMax,
      geoReady: geoReady,
      idTypes: idTypes ?? _idGen,
      ocrDniEnabled: ocrDniEnabled,
      legalPack: legalPack ?? iso.toLowerCase(),
      labelNivel1: labelNivel1 ?? 'Provincia',
      labelNivel2: labelNivel2 ?? 'Partido / Departamento',
      labelNivel3: labelNivel3 ?? 'Localidad',
      geoLevels: geoLevels,
    );
  }

  static final Map<String, CountryProfile> _byIso = {
    'AR': _row(
      iso: 'AR',
      name: 'Argentina',
      currency: 'ARS',
      dialCode: '+54',
      phoneExample: '+5491112345678',
      phoneMin: 13,
      phoneMax: 13,
      idTypes: _idAr,
      geoReady: true,
      ocrDniEnabled: true,
      legalPack: 'ar',
    ),
    'UY': _row(
      iso: 'UY',
      name: 'Uruguay',
      currency: 'UYU',
      dialCode: '+598',
      phoneExample: '+59899123456',
      phoneMin: 10,
      phoneMax: 11,
      idTypes: _idUy,
      geoReady: true,
      labelNivel1: 'Departamento',
      labelNivel2: 'Departamento',
      labelNivel3: 'Localidad',
      geoLevels: 2,
    ),
    'CL': _row(
      iso: 'CL',
      name: 'Chile',
      currency: 'CLP',
      dialCode: '+56',
      phoneExample: '+56912345678',
      phoneMin: 10,
      phoneMax: 11,
      idTypes: _idCl,
      geoReady: true,
      labelNivel1: 'Región',
      labelNivel2: 'Provincia',
      labelNivel3: 'Comuna',
    ),
    'PY': _row(
      iso: 'PY',
      name: 'Paraguay',
      currency: 'PYG',
      dialCode: '+595',
      phoneExample: '+595981123456',
      phoneMin: 11,
      phoneMax: 12,
    ),
    'BO': _row(
      iso: 'BO',
      name: 'Bolivia',
      currency: 'BOB',
      dialCode: '+591',
      phoneExample: '+59171234567',
      phoneMin: 10,
      phoneMax: 11,
    ),
    'PE': _row(
      iso: 'PE',
      name: 'Perú',
      currency: 'PEN',
      dialCode: '+51',
      phoneExample: '+51987654321',
      phoneMin: 10,
      phoneMax: 11,
    ),
    'EC': _row(
      iso: 'EC',
      name: 'Ecuador',
      currency: 'USD',
      dialCode: '+593',
      phoneExample: '+593991234567',
      phoneMin: 11,
      phoneMax: 12,
    ),
    'CO': _row(
      iso: 'CO',
      name: 'Colombia',
      currency: 'COP',
      dialCode: '+57',
      phoneExample: '+573001234567',
      phoneMin: 11,
      phoneMax: 12,
    ),
    'VE': _row(
      iso: 'VE',
      name: 'Venezuela',
      currency: 'VES',
      dialCode: '+58',
      phoneExample: '+584121234567',
      phoneMin: 11,
      phoneMax: 12,
    ),
    'MX': _row(
      iso: 'MX',
      name: 'México',
      currency: 'MXN',
      dialCode: '+52',
      phoneExample: '+525512345678',
      phoneMin: 12,
      phoneMax: 13,
      idTypes: _idMx,
    ),
    'GT': _row(
      iso: 'GT',
      name: 'Guatemala',
      currency: 'GTQ',
      dialCode: '+502',
      phoneExample: '+50251234567',
      phoneMin: 11,
      phoneMax: 11,
    ),
    'HN': _row(
      iso: 'HN',
      name: 'Honduras',
      currency: 'HNL',
      dialCode: '+504',
      phoneExample: '+50491234567',
      phoneMin: 11,
      phoneMax: 11,
    ),
    'SV': _row(
      iso: 'SV',
      name: 'El Salvador',
      currency: 'USD',
      dialCode: '+503',
      phoneExample: '+50370123456',
      phoneMin: 11,
      phoneMax: 11,
    ),
    'NI': _row(
      iso: 'NI',
      name: 'Nicaragua',
      currency: 'NIO',
      dialCode: '+505',
      phoneExample: '+50581234567',
      phoneMin: 11,
      phoneMax: 11,
    ),
    'CR': _row(
      iso: 'CR',
      name: 'Costa Rica',
      currency: 'CRC',
      dialCode: '+506',
      phoneExample: '+50683123456',
      phoneMin: 11,
      phoneMax: 11,
    ),
    'PA': _row(
      iso: 'PA',
      name: 'Panamá',
      currency: 'PAB',
      dialCode: '+507',
      phoneExample: '+50761234567',
      phoneMin: 11,
      phoneMax: 11,
    ),
    'DO': _row(
      iso: 'DO',
      name: 'República Dominicana',
      currency: 'DOP',
      dialCode: '+1809',
      phoneExample: '+18091234567',
      phoneMin: 11,
      phoneMax: 11,
    ),
    'CU': _row(
      iso: 'CU',
      name: 'Cuba',
      currency: 'CUP',
      dialCode: '+53',
      phoneExample: '+5351234567',
      phoneMin: 10,
      phoneMax: 11,
    ),
  };

  static String normalizeIso(String? raw) {
    final s = (raw ?? '').trim().toUpperCase();
    if (s.isEmpty) return defaultIso;
    if (_byIso.containsKey(s)) return s;
    return defaultIso;
  }

  static CountryProfile of(String? iso) =>
      _byIso[normalizeIso(iso)] ?? _byIso[defaultIso]!;

  static bool isSupported(String? iso) {
    final s = (iso ?? '').trim().toUpperCase();
    return _latamEs.contains(s);
  }

  static bool isLaunch(String? iso) {
    final s = (iso ?? '').trim().toUpperCase();
    return launchIsos.contains(s);
  }

  bool get launchReady => launchIsos.contains(iso);

  static List<CountryProfile> get all =>
      _byIso.values.toList(growable: false);

  /// AR, CL, UY primero; el resto después. No borra países del mapa.
  static List<CountryProfile> get listedForSelector {
    final launch = <CountryProfile>[];
    for (final iso in launchIsos) {
      final p = _byIso[iso];
      if (p != null) launch.add(p);
    }
    final rest = _byIso.values.where((p) => !launchIsos.contains(p.iso));
    return [...launch, ...rest];
  }

  /// Nombres para dropdowns (sin BR / ES / PT).
  static List<String> get supportedNames =>
      _byIso.values.map((e) => e.name).toList(growable: false);

  bool get legalPackReady => legalPack == 'ar';

  /// ISO del doc. Vacío o desconocido = AR (legado).
  static String isoOfData(Map<String, dynamic>? data) {
    return normalizeIso((data?['country_code'] ?? '').toString());
  }

  /// Matching intra-país. Legado sin campo cuenta como AR.
  static bool sameCountry(Map<String, dynamic>? data, String? viewerIso) {
    return isoOfData(data) == normalizeIso(viewerIso);
  }

  /// Campos faltantes para merge. Vacío si el doc ya tiene país.
  static Map<String, dynamic> legacyPatch(Map<String, dynamic>? data) {
    final patch = <String, dynamic>{};
    final rawCc = (data?['country_code'] ?? '').toString().trim();
    if (rawCc.isEmpty) {
      patch['country_code'] = defaultIso;
      final rawCur = (data?['currency'] ?? '').toString().trim();
      if (rawCur.isEmpty) patch['currency'] = defaultCurrency;
      return patch;
    }
    final profile = of(rawCc);
    if ((data?['country_code'] ?? '').toString().trim().toUpperCase() !=
        profile.iso) {
      patch['country_code'] = profile.iso;
    }
    final rawCur = (data?['currency'] ?? '').toString().trim();
    if (rawCur.isEmpty) patch['currency'] = profile.currency;
    return patch;
  }
}
