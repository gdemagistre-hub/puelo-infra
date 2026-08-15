#!/usr/bin/env python3
"""Reconstruye lib/Homepage.dart desde chunks base64 en tools/homepage_restore/."""
from pathlib import Path
import base64
import sys

root = Path(__file__).resolve().parent
repo = root.parent.parent
parts = []
for i in range(3):
    p = root / f"Homepage_b64_{i}.txt"
    if not p.exists():
        sys.exit(f"Falta {p}")
    parts.append(p.read_text().strip())

raw = base64.b64decode("".join(parts))
out = repo / "lib" / "Homepage.dart"
out.write_bytes(raw)
print(f"OK: {out} ({len(raw)} bytes)")
assert b"_mensajesNavItem" in raw and b"_buildClienteHome" in raw
assert b"part '" not in raw
print("Validado: badge + home cliente/prestador, sin part.")
