import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../scoring_service.dart';
import '../crypto/vault_session.dart';
import '../models/fiado.dart';

class FiadosStore extends ChangeNotifier {
  static const _prefix = 'fiados_v1_';

  final List<Fiado> _items = [];
  bool loaded = false;
  String? _uid;
  bool _cloudOk = false;
  String? lastCloudError;

  List<Fiado> get items => List.unmodifiable(_items);
  bool get syncedToCloud => _cloudOk;

  List<Fiado> get pendientes =>
      _items.where((f) => f.esPendiente).toList()
        ..sort((a, b) {
          final fa = a.fechaAcordada;
          final fb = b.fechaAcordada;
          if (fa != null && fb != null) return fa.compareTo(fb);
          if (fa != null) return -1;
          if (fb != null) return 1;
          return b.creado.compareTo(a.creado);
        });

  double get totalPendiente =>
      pendientes.fold<double>(0, (s, f) => s + f.monto);

  int get cantidadPendiente => pendientes.length;

  String get _key => '$_prefix${_uid ?? 'anon'}';

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('fiados');
  }

  static const _sensitive = ['nombre', 'monto', 'nota'];
  static const _numeric = {'monto'};

  /// Cifra sensibles y deja en claro lo que el batch de vencimientos necesita.
  Future<Map<String, dynamic>> _toCloud(Fiado f) async {
    final clear = f.toJson();
    final vault = VaultSession.instance;
    Map<String, dynamic> out;
    if (!vault.isUnlocked) {
      out = Map<String, dynamic>.from(clear);
    } else {
      out = await vault.sealMap(clear, sensitiveKeys: _sensitive);
    }
    // Siempre en claro (el cron de FCM no tiene la DEK del usuario).
    out['estado'] = f.estado.name;
    out['vto_dia'] = f.vtoDia;
    out['fechaAcordada'] = f.fechaAcordada?.toIso8601String();
    out['notificado_vto_dia'] = f.notificadoVtoDia;
    out['owner_uid'] = _uid; // redunda path; útil en collectionGroup
    return out;
  }

  Future<Fiado?> _fromCloud(Map<String, dynamic> data, String docId) async {
    try {
      var open = data;
      final vault = VaultSession.instance;
      if (data['enc'] == true && vault.isUnlocked) {
        open = await vault.openMap(
          data,
          sensitiveKeys: _sensitive,
          numericKeys: _numeric,
        );
      }
      open['id'] = open['id'] ?? docId;
      return Fiado.fromJson(open);
    } catch (e) {
      debugPrint('Fiado decrypt skip: $e');
      return null;
    }
  }

  Future<void> loadForUser(String? uid) async {
    _uid = uid;
    loaded = false;
    _cloudOk = false;
    lastCloudError = null;
    notifyListeners();
    _items.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          try {
            _items.add(Fiado.fromJson(Map<String, dynamic>.from(e as Map)));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('FiadosStore.local: $e');
    }

    if (uid != null && uid.isNotEmpty) {
      try {
        final snap = await _col!.get(const GetOptions(source: Source.server));
        if (snap.docs.isNotEmpty) {
          _items.clear();
          for (final doc in snap.docs) {
            final data = Map<String, dynamic>.from(doc.data());
            final f = await _fromCloud(data, doc.id);
            if (f != null) _items.add(f);
          }
          await _persistLocal();
        } else if (_items.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final f in _items) {
            batch.set(_col!.doc(f.id), {
              ...await _toCloud(f),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
        _cloudOk = true;
        lastCloudError = null;
      } catch (e) {
        debugPrint('FiadosStore.cloud: $e');
        _cloudOk = false;
        lastCloudError = e.toString();
      }
    }

    loaded = true;
    notifyListeners();
    unawaited(_syncStatsNegocio());
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _cloudSet(Fiado f) async {
    final col = _col;
    if (col == null) throw StateError('Sin usuario');
    await col.doc(f.id).set({
      ...await _toCloud(f),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Phase 0.1: conteos de fiados → stats_negocio (sin montos).
  Future<void> _syncStatsNegocio() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final nPend = _items.where((f) => f.esPendiente).length;
    final nCobr = _items.where((f) => !f.esPendiente).length;
    await ScoringService.actualizarStatsNegocio(
      uid: uid,
      nFiadosPendientes: nPend,
      nFiadosCobrados: nCobr,
    );
  }

  Future<bool> add(Fiado fiado) async {
    _items.insert(0, fiado);
    notifyListeners();
    await _persistLocal();
    try {
      await _cloudSet(fiado);
      _cloudOk = true;
      lastCloudError = null;
      notifyListeners();
      unawaited(_syncStatsNegocio());
      return true;
    } catch (e) {
      _cloudOk = false;
      lastCloudError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(Fiado fiado) async {
    final i = _items.indexWhere((e) => e.id == fiado.id);
    if (i < 0) return false;
    _items[i] = fiado;
    notifyListeners();
    await _persistLocal();
    try {
      await _cloudSet(fiado);
      _cloudOk = true;
      lastCloudError = null;
      notifyListeners();
      unawaited(_syncStatsNegocio());
      return true;
    } catch (e) {
      _cloudOk = false;
      lastCloudError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persistLocal();
    try {
      await _col?.doc(id).delete();
      _cloudOk = true;
      notifyListeners();
      unawaited(_syncStatsNegocio());
      return true;
    } catch (e) {
      _cloudOk = false;
      lastCloudError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> marcarCobrado(String id, {double? montoCobrado}) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return false;
    final f = _items[i];
    if (!f.esPendiente) return false;
    final updated = f.copyWith(
      estado: EstadoFiado.cobrado,
      cobradoAt: DateTime.now(),
      monto: montoCobrado ?? f.monto,
    );
    return update(updated);
  }
}
