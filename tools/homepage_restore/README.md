# Restore Homepage completo

El archivo `lib/Homepage.dart` completo (~44 KB) con Home rico + badge de mensajes se reconstruye así:

```bash
python3 tools/homepage_restore/rebuild.py
git add lib/Homepage.dart
git commit -m "RESTORE Homepage completo + badge pendientes"
git push origin main
```

Incluye:
- Home cliente (oficios YPF + banner confianza + typeahead)
- Home prestador (confianza + tarjeta digital + tips)
- Badge ámbar en tab Mensajes con cantidad de recibos pendientes de atender
