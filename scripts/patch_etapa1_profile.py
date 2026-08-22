#!/usr/bin/env python3
"""Patch Homepage + mensajes_detalle for profileRevision (Etapa 1)."""
from pathlib import Path
import re
import sys

def patch_mensajes():
    p = Path("lib/mensajes/mensajes_detalle.dart")
    t = p.read_text()
    if "notifyProfileChanged" in t:
        print("mensajes_detalle: already patched")
        return False
    # Insert notify after datosCompletos assignment block
    pattern = re.compile(
        r"(session\.datosCompletos = \{[\s\S]*?'cantidadEvaluadores': n,\s*\};)\s*(\n  \})",
        re.M,
    )
    m = pattern.search(t)
    if not m:
        print("mensajes_detalle: pattern not found", file=sys.stderr)
        sys.exit(1)
    t = t[: m.start()] + m.group(1) + "\n    session.notifyProfileChanged();" + m.group(2) + t[m.end() :]
    # Also notify early return path if invalidate-only
    t = t.replace(
        "session.invalidateHomeCache();\n    final nRaw = result['n_evaluaciones'];",
        "final nRaw = result['n_evaluaciones'];",
        1,
    )
    # snackbars
    for a, b in [
        (
            "Evaluación publicada con tu respuesta. Volvé a Home para ver las estrellas.",
            "Evaluación publicada. Las estrellas ya se actualizaron en tu perfil.",
        ),
        (
            "Evaluación aceptada. Volvé a Home para ver las estrellas en tu perfil.",
            "Evaluación aceptada. Las estrellas ya se actualizaron en tu perfil.",
        ),
    ]:
        t = t.replace(a, b)
    p.write_text(t)
    print("mensajes_detalle: patched")
    return True

def patch_homepage():
    p = Path("lib/Homepage.dart")
    h = p.read_text()
    changed = False
    if "_onProfileRevision" not in h:
        marker = "bool _tourCheckDone = false;"
        if marker not in h:
            print("Homepage: tour flag missing", file=sys.stderr)
            sys.exit(1)
        h = h.replace(
            marker,
            marker
            + "\n\n  void _onProfileRevision() {\n"
            + "    if (!mounted) return;\n"
            + "    setState(() {});\n"
            + "    if (_currentIndex == 0) {\n"
            + "      _refrescarDatosSesion();\n"
            + "    }\n"
            + "  }",
            1,
        )
        changed = True
    if "profileRevision.addListener" not in h:
        if "super.initState();\n    _detectarRol();" not in h:
            print("Homepage: initState marker missing", file=sys.stderr)
            sys.exit(1)
        h = h.replace(
            "super.initState();\n    _detectarRol();",
            "super.initState();\n    UserSession().profileRevision.addListener(_onProfileRevision);\n    _detectarRol();",
            1,
        )
        changed = True
    if "profileRevision.removeListener" not in h:
        if "void dispose() {\n    _searchCtrl.dispose();" not in h:
            print("Homepage: dispose marker missing", file=sys.stderr)
            sys.exit(1)
        h = h.replace(
            "void dispose() {\n    _searchCtrl.dispose();",
            "void dispose() {\n    UserSession().profileRevision.removeListener(_onProfileRevision);\n    _searchCtrl.dispose();",
            1,
        )
        changed = True
    if changed:
        p.write_text(h)
        print("Homepage: patched")
    else:
        print("Homepage: already patched")
    return changed

if __name__ == "__main__":
    a = patch_mensajes()
    b = patch_homepage()
    print("done", a or b)
