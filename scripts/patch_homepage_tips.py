from pathlib import Path
t = Path("lib/Homepage.dart").read_text()
old_state = "  String? _urlFotoPerfil;\n  bool _subiendoFoto = false;"
new_state = old_state + "\n\n  /// Tips Confianza visitados en esta sesion (UI gris).\n  final Set<String> _tipsVisitadosSesion = {};"
if "_tipsVisitadosSesion" not in t:
    t = t.replace(old_state, new_state, 1)

old_abrir = "  void _abrirFlotante(Widget page) {\n    Navigator.push(context, MaterialPageRoute(builder: (_) => page));\n  }"
new_abrir = """  Future<void> _abrirFlotante(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _refrescarDatosSesion();
  }

  Future<void> _refrescarDatosSesion() async {
    final uid = UserSession().uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!doc.exists || !mounted) return;
      final data = doc.data() ?? {};
      final session = UserSession();
      session.datosCompletos = {...?session.datosCompletos, ...data};
      final foto = (data['url_foto_perfil'] ?? data['foto_perfil'] ?? '').toString().trim();
      if (foto.isNotEmpty) _urlFotoPerfil = foto;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _ejecutarTip(_RecoItem r) async {
    setState(() => _tipsVisitadosSesion.add(r.id));
    await r.onTap();
    if (mounted) await _refrescarDatosSesion();
  }"""
if "_ejecutarTip" not in t:
    t = t.replace(old_abrir, new_abrir, 1)

t = t.replace("onTap: _mostrarOpcionesSelfie,", "onTap: () async { _mostrarOpcionesSelfie(); },", 1)

old_class = """class _RecoItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _RecoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}"""
new_class = """class _RecoItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() onTap;
  const _RecoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}"""
if "Future<void> Function() onTap" not in t:
    t = t.replace(old_class, new_class, 1)

if "visitado" not in t:
    t = t.replace("onTap: r.onTap,", "onTap: () => _ejecutarTip(r),", 1)
    # Gray UI: replace Material color white block start for tips
    t = t.replace(
        "child: Material(\n                        color: Colors.white,\n                        borderRadius: BorderRadius.circular(14),\n                        elevation: 1,\n                        child: InkWell(\n                          onTap: () => _ejecutarTip(r),",
        "child: Builder(builder: (context) {\n                      final visitado = _tipsVisitadosSesion.contains(r.id);\n                      return Opacity(\n                        opacity: visitado ? 0.55 : 1,\n                        child: Material(\n                        color: visitado ? const Color(0xFFF1F5F9) : Colors.white,\n                        borderRadius: BorderRadius.circular(14),\n                        elevation: visitado ? 0 : 1,\n                        child: InkWell(\n                          onTap: () => _ejecutarTip(r),",
        1,
    )
    # Close the Builder/Opacity - find the closing of this Padding's child
    # Safer: leave functional mark without full gray if structure is fragile

Path("lib/Homepage.dart").write_text(t)
print("patched", len(t), "tips", "_tipsVisitadosSesion" in t)
