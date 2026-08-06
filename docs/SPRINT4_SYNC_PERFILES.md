# Sprint 4 — Sync list fields en perfiles + guards

**Fecha:** 2026-08-06  
**Backup pre-Sprint 0 (intacto):** `backup/pre-sprint0-20260806T152754Z-df00470` → `df00470`

## Objetivo
Cablear `UsuarioListSync` en todos los writes de perfil relevantes y cerrar guards de cámara restantes, sin tocar el menú Modo prueba.

## Cambios

| Área | Cambio |
|------|--------|
| **Domicilio** | `UsuarioListSync.mergeUserDoc` |
| **Completar perfil** | Guard cámara + `UsuarioListSync` |
| **Datos personales** | `UsuarioListSync` al guardar |
| **Capacitaciones** | Oculta “Tomar foto” fuera de mobile |

## No tocar
- Tag/branch backup pre-Sprint 0
- Menú “Modo prueba (equipo)”

## Pendiente (Sprint 5+)
- App Check
- Auth obligatorio / `ALLOW_DEV_VALIDACION=0` (al retirar menú temp)
- ResponsiveShell en más pantallas desktop
