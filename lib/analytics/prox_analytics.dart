import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/app_env.dart';
import '../user_session.dart';

/// Telemetría de Prox orientada a producto y performance.
///
/// Seguridad / privacidad:
/// - No envía nombre, email, teléfono, documento ni direcciones.
/// - `uid` es el id de sesión de la app (opcional); no se envían tokens.
/// - Mensajes de error se recortan y se limpian de emails/teléfonos.
/// - Buffer + rate-limit cliente + cap rules: máx 40 docs/día/uid.
/// - Fallos de analytics nunca rompen la UX (todo en try/catch).
class ProxAnalytics {
  ProxAnalytics._();
  static final ProxAnalytics instance = ProxAnalytics._();

  static const int _maxBuffer = 20;
  static const int _maxEventsPerMinute = 40;
  static const int _maxSlotsPerDay = 40;
  static const Duration _flushEvery = Duration(seconds: 8);
  static const int _errorMsgMaxLen = 120;

  final _db = FirebaseFirestore.instance;
  final _buffer = <Map<String, dynamic>>[];
  final _screenEnteredAt = <String, DateTime>{};
  final _screenLoadStartedAt = <String, DateTime>{};

  String? _sessionId;
  String? _lastScreen;
  DateTime? _sessionStartedAt;
  Timer? _flushTimer;
  int _eventsThisMinute = 0;
  DateTime _minuteWindowStart = DateTime.now();
  bool _flushing = false;
  bool _enabled = true;
  String? _slotDay;
  int _slotForDay = 0;

  String get sessionId {
    _sessionId ??= _newSessionId();
    return _sessionId!;
  }

  void startSession({String? role}) {
    _sessionId = _newSessionId();
    _sessionStartedAt = DateTime.now();
    _lastScreen = null;
    _screenEnteredAt.clear();
    track('session_start', props: {
      if (role != null) 'role': role,
      'env': AppEnv.label,
      'platform': kIsWeb ? 'web' : 'io',
    });
  }

  void endSession({String reason = 'app_exit'}) {
    final last = _lastScreen;
    if (last != null) {
      _flushScreenDwell(last);
    }
    final started = _sessionStartedAt;
    final durationMs = started == null
        ? null
        : DateTime.now().difference(started).inMilliseconds;
    track('session_end', props: {
      if (last != null) 'last_screen': last,
      if (durationMs != null) 'duration_ms': durationMs,
      'reason': reason,
    });
    unawaited(flush(force: true));
  }

  /// Marca inicio de carga de una pantalla (antes del await de datos).
  void screenLoadStart(String screen) {
    _screenLoadStartedAt[screen] = DateTime.now();
  }

  /// Marca fin de carga; emite `screen_timing` si hubo start.
  void screenLoadEnd(String screen, {int? queryMs, bool ok = true}) {
    final started = _screenLoadStartedAt.remove(screen);
    final loadMs = started == null
        ? null
        : DateTime.now().difference(started).inMilliseconds;
    track('screen_timing', props: {
      'screen': screen,
      if (loadMs != null) 'load_ms': loadMs,
      if (queryMs != null) 'query_ms': queryMs,
      'ok': ok,
    });
  }

  /// Vista de pantalla + dwell de la anterior.
  void screenView(String screen, {String? role}) {
    if (_lastScreen != null && _lastScreen != screen) {
      _flushScreenDwell(_lastScreen!);
    }
    _lastScreen = screen;
    _screenEnteredAt[screen] = DateTime.now();
    track('screen_view', props: {
      'screen': screen,
      if (role != null) 'role': role,
    });
  }

  void action(String name, {String? screen, Map<String, dynamic>? props}) {
    track('action', props: {
      'name': name,
      if (screen != null) 'screen': screen,
      ...?_sanitizeProps(props),
    });
  }

  void error({
    required String screen,
    required String code,
    String? message,
  }) {
    track('error', props: {
      'screen': screen,
      'code': code,
      if (message != null) 'message': _sanitizeErrorMessage(message),
    });
  }

  void track(String type, {Map<String, dynamic>? props}) {
    if (!_enabled) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    if (!_allowEvent()) return;

    final uid = UserSession().uid ?? FirebaseAuth.instance.currentUser?.uid;
    final payload = <String, dynamic>{
      'type': type,
      'ts': FieldValue.serverTimestamp(),
      'client_ts': DateTime.now().toUtc().toIso8601String(),
      'session_id': sessionId,
      if (uid != null && uid.isNotEmpty) 'uid': uid,
      'env': AppEnv.label,
      if (props != null) ..._sanitizeProps(props)!,
    };

    _buffer.add(payload);
    if (_buffer.length >= _maxBuffer) {
      unawaited(flush());
    } else {
      _flushTimer ??= Timer(_flushEvery, () => unawaited(flush()));
    }
  }

  Future<void> flush({bool force = false}) async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_flushing) return;
    if (_buffer.isEmpty) return;
    if (!_enabled && !force) return;

    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null || authUid.isEmpty) {
      _buffer.clear();
      return;
    }

    _flushing = true;
    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      final ymd = _ymdArt();
      for (final event in batch) {
        final slot = _nextSlot(ymd);
        if (slot < 0) break;
        try {
          final docId =
              '${authUid}_${ymd}_${slot.toString().padLeft(2, '0')}';
          await _db.collection('analytics_events').doc(docId).set(event);
        } catch (e) {
          if (AppEnv.verboseLogging) {
            debugPrint('ProxAnalytics write skip: $e');
          }
        }
      }
    } catch (e) {
      if (AppEnv.verboseLogging) {
        debugPrint('ProxAnalytics flush error: $e');
      }
    } finally {
      _flushing = false;
    }
  }

  void _flushScreenDwell(String screen) {
    final entered = _screenEnteredAt.remove(screen);
    if (entered == null) return;
    final dwellMs = DateTime.now().difference(entered).inMilliseconds;
    if (dwellMs < 200) return; // ruido de navegación instantánea
    track('screen_exit', props: {
      'screen': screen,
      'dwell_ms': dwellMs,
    });
  }

  bool _allowEvent() {
    final now = DateTime.now();
    if (now.difference(_minuteWindowStart).inSeconds >= 60) {
      _minuteWindowStart = now;
      _eventsThisMinute = 0;
    }
    if (_eventsThisMinute >= _maxEventsPerMinute) return false;
    _eventsThisMinute++;
    return true;
  }

  int _nextSlot(String ymd) {
    if (_slotDay != ymd) {
      _slotDay = ymd;
      _slotForDay = 0;
    }
    if (_slotForDay >= _maxSlotsPerDay) return -1;
    final slot = _slotForDay;
    _slotForDay++;
    return slot;
  }

  static String _ymdArt([DateTime? now]) {
    final art = (now ?? DateTime.now()).toUtc().subtract(const Duration(hours: 3));
    final y = art.year.toString().padLeft(4, '0');
    final m = art.month.toString().padLeft(2, '0');
    final d = art.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Map<String, dynamic>? _sanitizeProps(Map<String, dynamic>? props) {
    if (props == null) return null;
    const blocked = {
      'email',
      'telefono',
      'phone',
      'celular',
      'nombre',
      'apellido',
      'documento',
      'dni',
      'calle',
      'password',
      'token',
      'whatsapp',
    };
    final out = <String, dynamic>{};
    props.forEach((k, v) {
      final key = k.toLowerCase();
      if (blocked.contains(key)) return;
      if (v is String && v.length > 200) {
        out[k] = v.substring(0, 200);
      } else if (v is num || v is bool || v is String) {
        out[k] = v;
      } else if (v == null) {
        // skip
      } else {
        out[k] = v.toString();
      }
    });
    return out;
  }

  String _sanitizeErrorMessage(String raw) {
    var s = raw;
    s = s.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[email]',
    );
    s = s.replaceAll(RegExp(r'\+?\d[\d\s\-]{8,}\d'), '[num]');
    if (s.length > _errorMsgMaxLen) {
      s = s.substring(0, _errorMsgMaxLen);
    }
    return s;
  }

  String _newSessionId() {
    final r = Random.secure();
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final part = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
    return 's_$ts$part';
  }
}

/// Observer de rutas para screen_view automático.
class ProxRouteObserver extends NavigatorObserver {
  String? _nameOf(Route<dynamic>? route) {
    final n = route?.settings.name;
    if (n == null || n.isEmpty) return null;
    try {
      final uri = Uri.parse(n);
      return uri.path.isEmpty ? n : uri.path;
    } catch (_) {
      return n;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _nameOf(route);
    if (name != null) {
      ProxAnalytics.instance.screenView(name);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final name = _nameOf(newRoute);
    if (name != null) {
      ProxAnalytics.instance.screenView(name);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _nameOf(previousRoute);
    if (name != null) {
      ProxAnalytics.instance.screenView(name);
    }
  }
}
