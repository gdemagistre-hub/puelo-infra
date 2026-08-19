from pathlib import Path

def patch_session():
    p = Path('lib/user_session.dart')
    t = p.read_text()
    if 'Si el doc no tiene foto' in t:
        print('session already patched')
        return
    old = """        if (doc.exists && doc.data() != null) {
          data = doc.data()!;
        } else {"""
    new = """        if (doc.exists && doc.data() != null) {
          data = Map<String, dynamic>.from(doc.data()!);
          // Si el doc no tiene foto, usar la de Google Auth (no pisar selfie).
          final fp = (data['url_foto_perfil'] ?? data['foto_perfil'] ?? '')
              .toString()
              .trim();
          if (fp.isEmpty && (user.photoURL ?? '').trim().isNotEmpty) {
            data['url_foto_perfil'] = user.photoURL!.trim();
            data['foto_perfil_origen'] = data['foto_perfil_origen'] ?? 'google';
            try {
              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid)
                  .set({
                'url_foto_perfil': user.photoURL!.trim(),
                'foto_perfil_origen': 'google',
                'updated_at': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}
          }
        } else {"""
    if old not in t:
        raise SystemExit('session block not found')
    p.write_text(t.replace(old, new, 1))
    print('session patched')

def patch_homepage():
    p = Path('lib/Homepage.dart')
    t = p.read_text()
    if "import 'package:firebase_auth/firebase_auth.dart';" not in t:
        t = t.replace(
            "import 'package:cloud_firestore/cloud_firestore.dart';",
            "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_auth/firebase_auth.dart';",
            1,
        )
    old_init = """    final foto = (UserSession().datosCompletos?['url_foto_perfil'] ?? UserSession().datosCompletos?['foto_perfil'] ?? '').toString().trim();
    if (foto.isNotEmpty) _urlFotoPerfil = foto;"""
    new_init = """    var foto = (UserSession().datosCompletos?['url_foto_perfil'] ??
            UserSession().datosCompletos?['foto_perfil'] ??
            '')
        .toString()
        .trim();
    if (foto.isEmpty) {
      final authPhoto = FirebaseAuth.instance.currentUser?.photoURL?.trim() ?? '';
      if (authPhoto.isNotEmpty) foto = authPhoto;
    }
    if (foto.isNotEmpty) _urlFotoPerfil = foto;"""
    if old_init in t:
        t = t.replace(old_init, new_init, 1)
        print('homepage init patched')
    else:
        print('homepage init already or missing')

    old_av = """  Widget _buildAvatarHeader() {
    final hasFoto = _urlFotoPerfil != null && _urlFotoPerfil!.isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        image: hasFoto ? DecorationImage(image: NetworkImage(_urlFotoPerfil!), fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: hasFoto ? null : Text(_getInitials(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }"""
    new_av = """  Widget _buildAvatarHeader() {
    final hasFoto = _urlFotoPerfil != null && _urlFotoPerfil!.isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasFoto
          ? Image.network(
              _urlFotoPerfil!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Text(
                _getInitials(),
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Text(
                  _getInitials(),
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                );
              },
            )
          : Text(
              _getInitials(),
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
    );
  }"""
    if old_av in t:
        t = t.replace(old_av, new_av, 1)
        print('avatar patched')
    else:
        print('avatar already or missing')
    p.write_text(t)
    print('homepage braces', t.count('{') == t.count('}'))

if __name__ == '__main__':
    patch_session()
    patch_homepage()
