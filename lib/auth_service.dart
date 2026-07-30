import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_session.dart';
import 'analytics/prox_analytics.dart';

/// Autenticación real (Google ahora; Facebook / Apple después).
///
/// Flujo:
/// 1) Provider → Firebase Auth
/// 2) Asegura doc `usuarios/{uid}` (crea o merge de campos auth)
/// 3) Carga [UserSession]
///
/// El login por dropdown (impersonación) NO pasa por aquí.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// true si hay sesión Firebase Auth (no impersonación dev).
  bool get hasFirebaseAuth => currentUser != null;

  /// Google Sign-In → perfil Firestore → UserSession.
  Future<void> signInWithGoogle() async {
    final UserCredential cred;
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      provider.setCustomParameters({'prompt': 'select_account'});
      cred = await _auth.signInWithPopup(provider);
    } else {
      final googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) {
        throw AuthCancelledException();
      }
      final ga = await account.authentication;
      final oauth = GoogleAuthProvider.credential(
        accessToken: ga.accessToken,
        idToken: ga.idToken,
      );
      cred = await _auth.signInWithCredential(oauth);
    }

    final user = cred.user;
    if (user == null) {
      throw StateError('Google Auth no devolvió usuario');
    }

    final data = await ensureUserProfile(
      user,
      providerId: 'google',
    );
    UserSession().iniciarSesion(
      user.uid,
      data,
      authProvider: 'google',
      isDevImpersonation: false,
    );

    final esPrestador =
        data['es_trabajador'] == true || data['rol'] == 'trabajador';
    try {
      ProxAnalytics.instance.startSession(
        role: esPrestador ? 'prestador' : 'cliente',
      );
      ProxAnalytics.instance.action('login_google', screen: '/login');
    } catch (_) {}
  }

  /// Placeholder para el mismo patrón con Facebook.
  Future<void> signInWithFacebook() async {
    throw UnimplementedError(
      'Facebook Auth se habilita en una etapa siguiente (mismo patrón que Google).',
    );
  }

  /// Placeholder para el mismo patrón con Apple.
  Future<void> signInWithApple() async {
    throw UnimplementedError(
      'Apple Auth se habilita en una etapa siguiente (mismo patrón que Google).',
    );
  }

  /// Crea o actualiza `usuarios/{uid}` con datos del provider.
  ///
  /// Convención DB:
  /// - doc id = Firebase Auth uid
  /// - `auth_provider`: google | facebook | apple | email | dev
  /// - `auth_uid`: mismo uid
  /// - `email`, `url_foto_perfil` desde el provider si faltan
  Future<Map<String, dynamic>> ensureUserProfile(
    User user, {
    required String providerId,
  }) async {
    final ref = _db.collection('usuarios').doc(user.uid);
    final snap = await ref.get();

    final display = (user.displayName ?? '').trim();
    String nombre = '';
    String apellido = '';
    if (display.isNotEmpty) {
      final parts = display.split(RegExp(r'\s+'));
      nombre = parts.first;
      if (parts.length > 1) {
        apellido = parts.sublist(1).join(' ');
      }
    }

    if (!snap.exists) {
      final data = <String, dynamic>{
        'nombre': nombre,
        'apellido': apellido,
        'email': user.email ?? '',
        if (user.photoURL != null && user.photoURL!.isNotEmpty)
          'url_foto_perfil': user.photoURL,
        'auth_provider': providerId,
        'auth_uid': user.uid,
        'es_trabajador': false,
        'estado': 'activo',
        'creado_en': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      await ref.set(data);
      final created = await ref.get();
      return created.data() ?? data;
    }

    final existing = Map<String, dynamic>.from(snap.data()!);
    final patch = <String, dynamic>{
      'auth_provider': providerId,
      'auth_uid': user.uid,
      'updated_at': FieldValue.serverTimestamp(),
    };

    final existingEmail = (existing['email'] ?? '').toString().trim();
    if (existingEmail.isEmpty && (user.email ?? '').isNotEmpty) {
      patch['email'] = user.email;
    }

    final existingNombre = (existing['nombre'] ?? '').toString().trim();
    if (existingNombre.isEmpty && nombre.isNotEmpty) {
      patch['nombre'] = nombre;
    }
    final existingApellido = (existing['apellido'] ?? '').toString().trim();
    if (existingApellido.isEmpty && apellido.isNotEmpty) {
      patch['apellido'] = apellido;
    }

    final existingFoto = (existing['url_foto_perfil'] ?? '').toString().trim();
    if (existingFoto.isEmpty &&
        user.photoURL != null &&
        user.photoURL!.isNotEmpty) {
      patch['url_foto_perfil'] = user.photoURL;
    }

    // Si estaba pendiente de validación manual, al entrar con Google lo activamos.
    final estado = (existing['estado'] ?? '').toString();
    if (estado == 'pendiente_validacion' || estado.isEmpty) {
      patch['estado'] = 'activo';
    }

    await ref.set(patch, SetOptions(merge: true));
    final updated = await ref.get();
    return updated.data() ?? {...existing, ...patch};
  }

  /// Cierra Firebase Auth + Google Sign-In (si aplica) + UserSession.
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (e) {
      debugPrint('AuthService GoogleSignIn.signOut: $e');
    }
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService FirebaseAuth.signOut: $e');
    }
    await UserSession().cerrarSesion();
  }
}

/// El usuario cerró el selector de Google sin completar.
class AuthCancelledException implements Exception {
  @override
  String toString() => 'Inicio de sesión cancelado';
}
