import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

import 'user_session.dart';

/// Auth real (Google + Facebook web + email/password; Apple placeholder).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _fnRegion = 'us-east1';

  Future<bool> _sendAuthEmailCf({
    required String type,
    String? email,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: _fnRegion)
          .httpsCallable('sendAuthEmail');
      await callable.call(<String, dynamic>{
        'type': type,
        if (email != null && email.trim().isNotEmpty)
          'email': email.trim().toLowerCase(),
      });
      return true;
    } catch (e) {
      debugPrint('AuthService._sendAuthEmailCf ($type): $e');
      return false;
    }
  }

  User? get currentUser => _auth.currentUser;

  Map<String, dynamic>? authUserSnapshot() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'providers': user.providerData
          .map((p) => {
                'providerId': p.providerId,
                'uid': p.uid,
                'email': p.email,
                'displayName': p.displayName,
                'photoURL': p.photoURL,
              })
          .toList(),
    };
  }

  Future<void> signInWithGoogle() async {
    UserCredential cred;
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
      throw StateError('Google sign-in sin user');
    }

    final data = await ensureUserProfile(user, providerId: 'google');
    UserSession().iniciarSesion(
      user.uid,
      data,
      authProvider: 'google',
      isDevImpersonation: false,
    );
  }

  /// Facebook en web: redirect (popup falla mucho en móvil).
  /// Al volver, Splash + UserSession.restaurarSesion / getRedirectResult cierran el flujo.
  Future<void> signInWithFacebook() async {
    if (!kIsWeb) {
      throw AuthValidationException(
        'Facebook en Android/iOS se habilita después. Usá la web, Google o email.',
      );
    }

    final provider = FacebookAuthProvider();
    provider.addScope('email');
    provider.addScope('public_profile');
    await _auth.signInWithRedirect(provider);
  }

  Future<void> signInWithApple() async {
    throw UnimplementedError(
      'Apple Auth se habilita en una etapa siguiente (mismo patrón que Google).',
    );
  }

  Future<User> registerWithEmail({
    required String email,
    required String password,
    String? nombre,
    String? apellido,
  }) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || !e.contains('@')) {
      throw AuthValidationException('Ingresá un email válido.');
    }
    if (password.length < 6) {
      throw AuthValidationException(
        'La contraseña debe tener al menos 6 caracteres.',
      );
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: e,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw StateError('Registro sin user');
      }

      final display = [
        (nombre ?? '').trim(),
        (apellido ?? '').trim(),
      ].where((s) => s.isNotEmpty).join(' ');
      if (display.isNotEmpty) {
        await user.updateDisplayName(display);
        await user.reload();
      }

      final sentCf = await _sendAuthEmailCf(type: 'verify');
      if (!sentCf) {
        await user.sendEmailVerification(
          ActionCodeSettings(
            url: 'https://lifewalletpuelo.web.app/',
            handleCodeInApp: false,
          ),
        );
      }

      final ref = _db.collection('usuarios').doc(user.uid);
      await ref.set({
        'nombre': (nombre ?? '').trim(),
        'apellido': (apellido ?? '').trim(),
        'email': e,
        'auth_provider': 'password',
        'auth_uid': user.uid,
        'es_trabajador': false,
        'estado': 'pendiente_email',
        'email_verified': false,
        'creado_en': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return _auth.currentUser ?? user;
    } on FirebaseAuthException catch (e) {
      throw AuthValidationException(humanizeAuthError(e));
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || password.isEmpty) {
      throw AuthValidationException('Completá email y contraseña.');
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: e,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw StateError('Login sin user');
      }

      await user.reload();
      final refreshed = _auth.currentUser ?? user;

      if (!refreshed.emailVerified) {
        throw EmailNotVerifiedException(refreshed.email ?? e);
      }

      final data = await ensureUserProfile(refreshed, providerId: 'password');
      try {
        await _db.collection('usuarios').doc(refreshed.uid).set({
          'email_verified': true,
          'estado': 'activo',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      UserSession().iniciarSesion(
        refreshed.uid,
        {...data, 'email_verified': true, 'estado': 'activo'},
        authProvider: 'password',
        isDevImpersonation: false,
      );
    } on EmailNotVerifiedException {
      rethrow;
    } on AuthValidationException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthValidationException(humanizeAuthError(e));
    }
  }

  Future<bool> completeEmailVerificationIfReady() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null || !refreshed.emailVerified) return false;

    final data = await ensureUserProfile(refreshed, providerId: 'password');
    try {
      await _db.collection('usuarios').doc(refreshed.uid).set({
        'email_verified': true,
        'estado': 'activo',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    UserSession().iniciarSesion(
      refreshed.uid,
      {...data, 'email_verified': true, 'estado': 'activo'},
      authProvider: 'password',
      isDevImpersonation: false,
    );
    return true;
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthValidationException(
        'No hay una sesión pendiente. Volvé a registrarte o iniciá sesión.',
      );
    }
    if (user.emailVerified) return;
    try {
      final sentCf = await _sendAuthEmailCf(type: 'verify');
      if (!sentCf) {
        await user.sendEmailVerification(
          ActionCodeSettings(
            url: 'https://lifewalletpuelo.web.app/',
            handleCodeInApp: false,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      throw AuthValidationException(humanizeAuthError(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || !e.contains('@')) {
      throw AuthValidationException('Ingresá un email válido.');
    }
    try {
      final sentCf = await _sendAuthEmailCf(type: 'reset', email: e);
      if (!sentCf) {
        await _auth.sendPasswordResetEmail(
          email: e,
          actionCodeSettings: ActionCodeSettings(
            url: 'https://lifewalletpuelo.web.app/',
            handleCodeInApp: false,
          ),
        );
      }
    } on FirebaseAuthException catch (ex) {
      throw AuthValidationException(humanizeAuthError(ex));
    }
  }

  static String humanizeAuthError(Object? e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Ese email ya tiene una cuenta. Probá iniciar sesión.';
        case 'invalid-email':
          return 'El email no es válido.';
        case 'weak-password':
          return 'La contraseña es demasiado débil (mínimo 6 caracteres).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email o contraseña incorrectos.';
        case 'user-disabled':
          return 'Esta cuenta está deshabilitada.';
        case 'too-many-requests':
          return 'Demasiados intentos. Esperá un momento y probá de nuevo.';
        case 'network-request-failed':
          return 'Sin conexión. Revisá tu internet.';
        case 'operation-not-allowed':
          return 'Ese método de ingreso no está habilitado en Firebase.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Cancelaste el inicio de sesión.';
        case 'account-exists-with-different-credential':
          return 'Ese email ya está asociado a Google o email. Entrá con ese método.';
        default:
          return e.message?.isNotEmpty == true
              ? e.message!
              : 'Error de autenticación (${e.code}).';
      }
    }
    final s = '$e';
    if (s.length > 160) return '${s.substring(0, 157)}…';
    return s;
  }

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

    for (final p in user.providerData) {
      final pid = p.providerId;
      if ((pid == 'google.com' || pid == 'facebook.com') &&
          (p.displayName ?? '').trim().isNotEmpty) {
        final d = p.displayName!.trim();
        final parts = d.split(RegExp(r'\s+'));
        nombre = parts.first;
        apellido = parts.length > 1 ? parts.sublist(1).join(' ') : apellido;
        break;
      }
    }

    final photo = (user.photoURL ?? '').trim().isNotEmpty
        ? user.photoURL!.trim()
        : user.providerData
            .map((p) => (p.photoURL ?? '').trim())
            .firstWhere((u) => u.isNotEmpty, orElse: () => '');

    final email = (user.email ?? '').trim().isNotEmpty
        ? user.email!.trim()
        : user.providerData
            .map((p) => (p.email ?? '').trim())
            .firstWhere((e) => e.isNotEmpty, orElse: () => '');

    final fotoOrigen = providerId == 'password' ? 'password' : providerId;

    if (!snap.exists) {
      final data = <String, dynamic>{
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        if (photo.isNotEmpty) 'url_foto_perfil': photo,
        if (photo.isNotEmpty) 'foto_perfil_origen': fotoOrigen,
        'auth_provider': providerId,
        'auth_uid': user.uid,
        'es_trabajador': false,
        'estado': 'activo',
        'email_verified': user.emailVerified,
        'creado_en': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      await ref.set(data);
      final created = await ref.get();
      return Map<String, dynamic>.from(created.data() ?? data);
    }

    final existing = Map<String, dynamic>.from(snap.data()!);
    final patch = <String, dynamic>{
      'auth_provider': providerId,
      'auth_uid': user.uid,
      'updated_at': FieldValue.serverTimestamp(),
      'email_verified': user.emailVerified,
    };

    if (nombre.isNotEmpty) patch['nombre'] = nombre;
    if (apellido.isNotEmpty) patch['apellido'] = apellido;
    if (email.isNotEmpty) patch['email'] = email;
    final existingPhoto = (existing['url_foto_perfil'] ??
            existing['foto_perfil'] ??
            '')
        .toString()
        .trim();
    final esSelfiePropia = existingPhoto.contains('/usuarios/') &&
        existingPhoto.contains('foto_perfil');
    if (existingPhoto.isEmpty && photo.isNotEmpty) {
      patch['url_foto_perfil'] = photo;
      patch['foto_perfil_origen'] = fotoOrigen;
    } else if (esSelfiePropia) {
      // Conservar selfie.
    }

    final estado = (existing['estado'] ?? '').toString();
    if (estado == 'pendiente_validacion' ||
        estado == 'pendiente_email' ||
        estado.isEmpty) {
      patch['estado'] = 'activo';
    }

    await ref.set(patch, SetOptions(merge: true));
    final updated = await ref.get();
    final out =
        Map<String, dynamic>.from(updated.data() ?? {...existing, ...patch});
    final outPhoto = (out['url_foto_perfil'] ?? out['foto_perfil'] ?? '')
        .toString()
        .trim();
    if (outPhoto.isEmpty && photo.isNotEmpty) {
      out['url_foto_perfil'] = photo;
      out['foto_perfil_origen'] = fotoOrigen;
      try {
        await ref.set({
          'url_foto_perfil': photo,
          'foto_perfil_origen': fotoOrigen,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    return out;
  }

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

class AuthCancelledException implements Exception {
  @override
  String toString() => 'AuthCancelledException';
}

class EmailNotVerifiedException implements Exception {
  final String email;
  EmailNotVerifiedException(this.email);
  @override
  String toString() => 'EmailNotVerifiedException($email)';
}

class AuthValidationException implements Exception {
  final String message;
  AuthValidationException(this.message);
  @override
  String toString() => message;
}
