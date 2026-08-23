#!/usr/bin/env python3
"""Patch Homepage + registroTrabajador for 5.6 home-mode persist."""
from pathlib import Path


def main() -> None:
    hp = Path('lib/Homepage.dart')
    t = hp.read_text(encoding='utf-8')
    if 'PLACEHOLDER' in t or 'SEE_FILE' in t:
        raise SystemExit('Homepage is PLACEHOLDER — abort')

    if 'bool _landingRolAplicado' not in t:
        old = '  bool _puedeSerAmbos = false;\n'
        new = '  bool _puedeSerAmbos = false;\n  bool _landingRolAplicado = false;\n'
        if old not in t:
            raise SystemExit('anchor _puedeSerAmbos missing')
        t = t.replace(old, new, 1)

    old_det = (
        "  void _detectarRol() {\n"
        "    final data = UserSession().datosCompletos;\n"
        "    final esPrestador = data?['es_trabajador'] == true || data?['rol'] == 'trabajador';\n"
        "    setState(() {\n"
        "      _puedeSerAmbos = esPrestador;\n"
        "      _modoPrestador = widget.initialModoPrestador ?? esPrestador;\n"
        "    });\n"
        "  }"
    )
    old_det2 = (
        "  void _detectarRol() {\n"
        "    final session = UserSession();\n"
        "    final esPrestador = session.esPrestador;\n"
        "    setState(() {\n"
        "      _puedeSerAmbos = esPrestador;\n"
        "      _modoPrestador =\n"
        "          widget.initialModoPrestador ?? session.preferredHomeModoPrestador;\n"
        "    });\n"
        "  }"
    )
    new_det = (
        "  void _detectarRol() {\n"
        "    final session = UserSession();\n"
        "    final esPrestador = session.esPrestador;\n"
        "    setState(() {\n"
        "      _puedeSerAmbos = esPrestador;\n"
        "      if (!esPrestador) {\n"
        "        _modoPrestador = false;\n"
        "      } else if (!_landingRolAplicado && widget.initialModoPrestador != null) {\n"
        "        _modoPrestador = widget.initialModoPrestador!;\n"
        "        _landingRolAplicado = true;\n"
        "      } else {\n"
        "        _modoPrestador = session.preferredHomeModoPrestador;\n"
        "        _landingRolAplicado = true;\n"
        "      }\n"
        "    });\n"
        "  }"
    )
    start = t.find('void _detectarRol')
    det = t[start: start + 800] if start >= 0 else ''
    if 'if (!esPrestador)' in det and '_landingRolAplicado' in det and 'preferredHomeModoPrestador' in det:
        print('Homepage _detectarRol already patched')
    elif old_det in t:
        t = t.replace(old_det, new_det, 1)
        print('Homepage _detectarRol patched from GH original')
    elif old_det2 in t:
        t = t.replace(old_det2, new_det, 1)
        print('Homepage _detectarRol patched from partial 5.6')
    else:
        raise SystemExit('Homepage _detectarRol block not found')

    old_tog = (
        "  void _toggleModoPrestador() {\n"
        "    setState(() => _modoPrestador = !_modoPrestador);\n"
        "    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartHomeTour());\n"
        "  }"
    )
    new_tog = (
        "  void _toggleModoPrestador() {\n"
        "    setState(() => _modoPrestador = !_modoPrestador);\n"
        "    UserSession().persistHomeModoPrestador(_modoPrestador);\n"
        "    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartHomeTour());\n"
        "  }"
    )
    if 'persistHomeModoPrestador(_modoPrestador)' in t:
        print('Homepage toggle already persists')
    elif old_tog in t:
        t = t.replace(old_tog, new_tog, 1)
        print('Homepage toggle patched')
    else:
        raise SystemExit('Homepage _toggleModoPrestador block not found')

    if 'Sli ver' in t or 'ofiver' in t:
        raise SystemExit('typo detected')
    if t.count('{') != t.count('}'):
        raise SystemExit('brace mismatch Homepage')
    hp.write_text(t, encoding='utf-8')
    print('Homepage ok', hp.stat().st_size)

    rt = Path('lib/registroTrabajador.dart')
    r = rt.read_text(encoding='utf-8')
    if 'PLACEHOLDER' in r or 'SEE_FILE' in r:
        raise SystemExit('registroTrabajador is PLACEHOLDER — abort')
    needle = (
        "    session.invalidateHomeCache();\n"
        "    if (!persist || uid == null || uid.isEmpty) return;"
    )
    repl = (
        "    session.invalidateHomeCache();\n"
        "    session.persistHomeModoPrestador(true);\n"
        "    if (!persist || uid == null || uid.isEmpty) return;"
    )
    if 'persistHomeModoPrestador(true)' in r:
        print('registro already persists home modo')
    elif needle in r:
        r = r.replace(needle, repl, 1)
        rt.write_text(r, encoding='utf-8')
        print('registro persist patched')
    else:
        raise SystemExit('registro anchor missing')
    print('registro ok', rt.stat().st_size)


if __name__ == '__main__':
    main()
