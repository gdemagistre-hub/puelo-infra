#!/usr/bin/env python3
from pathlib import Path

p = Path("lib/Homepage.dart")
t = p.read_text()
if "contactos_prestador_card.dart" in t:
    print("Homepage already patched")
    raise SystemExit(0)

old_imp = "import 'widgets/dev_auth_banner.dart';\n"
new_imp = (
    "import 'widgets/dev_auth_banner.dart';\n"
    "import 'contacto/contactos_prestador_card.dart';\n"
)
if old_imp not in t:
    raise SystemExit("import marker missing")
t = t.replace(old_imp, new_imp, 1)

old = """        Builder(
          builder: (context) {
            final recos = _recomendacionesPrestador(_dp);"""
new = """        ContactosPrestadorCard(
          onIrMensajes: () => _selectTab(3),
        ),
        Builder(
          builder: (context) {
            final recos = _recomendacionesPrestador(_dp);"""
if old not in t:
    raise SystemExit("prestador recos marker missing")
t = t.replace(old, new, 1)

if t.count("{") != t.count("}"):
    raise SystemExit(f"braces {t.count('{')} {t.count('}')}")
p.write_text(t)
print("Homepage 5.9 patched")
