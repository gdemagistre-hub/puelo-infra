# Sprint 4 — closeout

**Fecha:** 2026-08-06  
**Backup pre-Sprint 0 (intacto):** `backup/pre-sprint0-20260806T152754Z-df00470` → `df00470`

## En main

| Área | Estado |
|------|--------|
| Domicilio | `UsuarioListSync.mergeUserDoc` |
| Capacitaciones | `pickImageSource` (sin cámara en desktop) |
| Helper `pickImageSource` | `lib/widgets/image_source_sheet.dart` |
| Helper `UsuarioListSync` | `lib/usuario_list_sync.dart` |
| Script parches | `scripts/patches/sprint4_wire_listsync.sh` |

## Aplicar localmente (completar + datos)

```bash
bash scripts/patches/sprint4_wire_listsync.sh
```

Eso cablea:

- **completar_perfil**: guard cámara + `UsuarioListSync`
- **datosPersonalesflotante**: `UsuarioListSync` al guardar

## No tocar

- Tag backup pre-Sprint 0
- Menú Modo prueba (equipo)

## Sprint 5+

- App Check
- `ALLOW_DEV_VALIDACION=0` al retirar menú temp
- Auth obligatorio en writes
- ResponsiveShell desktop end-to-end
