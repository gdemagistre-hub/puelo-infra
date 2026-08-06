# Sprint 5 — cierre list fields + plan App Check

**Fecha:** 2026-08-06  
**Backup pre-Sprint 0 (intacto):** `backup/pre-sprint0-20260806T152754Z-df00470` → `df00470`

## Objetivo
Cerrar `UsuarioListSync` en completar perfil y documentar App Check sin romper el menú Modo prueba.

## Cambios en código

| Área | Estado |
|------|--------|
| **Completar perfil** | Guard cámara + `UsuarioListSync.mergeUserDoc` |
| **Datos personales** | Patch listo en `scripts/patches/sprint5_completar_datos.patch` |

### Aplicar datos personales localmente

```bash
git apply scripts/patches/sprint5_completar_datos.patch
# o solo la parte de datos:
bash scripts/patches/sprint4_wire_listsync.sh
```

## App Check (preparación)

1. Habilitar en consola Firebase (modo **monitor**, no enforce).
2. Providers: Play Integrity / DeviceCheck / reCAPTCHA v3 (web).
3. **No enforce** mientras exista el menú Modo prueba sin Auth real.

## No tocar
- Tag backup pre-Sprint 0
- Menú “Modo prueba (equipo)”
- `ALLOW_DEV_VALIDACION`

## Sprint 6+
- Enforce App Check
- Auth obligatorio al retirar menú temp
- ResponsiveShell desktop end-to-end
