# Sprint 5 — aplicar patch listsync (obligatorio en local)

**Backup pre-Sprint 0 (intacto):** `backup/pre-sprint0-20260806T152754Z-df00470` → `df00470`

## Por qué local

Los archivos `completar_perfil.dart` (~33 KB) y `datosPersonalesflotante.dart` (~40 KB) no se materializan de forma fiable vía push remoto en este entorno. El **patch unificado ya está en `main`** y se aplica en un comando.

## Comando (desde la raíz del repo)

```bash
git checkout main
git pull origin main
git apply scripts/patches/sprint5_completar_datos.patch
# verificar
grep -n UsuarioListSync lib/completar_perfil.dart lib/datosPersonalesflotante.dart
git add lib/completar_perfil.dart lib/datosPersonalesflotante.dart
git commit -m "Sprint 5: UsuarioListSync en completar + datos personales"
git push origin main
```

### Qué cambia el patch

| Archivo | Cambio |
|---------|--------|
| `completar_perfil.dart` | Guard cámara (`PlatformCapabilities`) + `UsuarioListSync.mergeUserDoc` |
| `datosPersonalesflotante.dart` | `UsuarioListSync.mergeUserDoc` al guardar |

## App Check (consola Firebase) — modo monitor

1. Firebase Console → App Check → registrar apps (Android / iOS / Web).
2. Providers sugeridos:
   - Android: Play Integrity
   - iOS: DeviceCheck / App Attest
   - Web: reCAPTCHA v3
3. Dejar **enforcement OFF** (solo monitor) mientras exista el menú **Modo prueba (equipo)**.
4. Revisar métricas 1–2 semanas antes de enforce.

## No tocar

- Tag/branch `backup/pre-sprint0-*`
- Menú temporal de login
- `ALLOW_DEV_VALIDACION` (sigue activo para el equipo)

## Ramas a evitar

- `sprint5/wire-completar-datos` — tuvo placeholders; **no mergear**
- `sprint5/apply-listsync-patch` — experimental; preferir el patch de `main`
