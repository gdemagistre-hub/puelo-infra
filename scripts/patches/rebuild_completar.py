#!/usr/bin/env python3
import base64, pathlib
parts = []
for i in range(4):
    parts.append(pathlib.Path(f"scripts/patches/completar_b64_{i}.txt").read_text().strip())
data = base64.b64decode("".join(parts))
pathlib.Path("lib/completar_perfil.dart").write_bytes(data)
print("rebuilt completar", len(data))
