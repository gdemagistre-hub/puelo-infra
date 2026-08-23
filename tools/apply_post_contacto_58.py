#!/usr/bin/env python3
from pathlib import Path

def patch_buscador():
    p = Path("lib/buscadorPrestadores.dart")
    t = p.read_text()
    if "post_contacto_sheet.dart" in t:
        print("buscador already patched")
        return
    old_imp = "import 'contacto_service.dart';\n"
    new_imp = (
        "import 'contacto_service.dart';\n"
        "import 'contacto/post_contacto_sheet.dart';\n"
    )
    if old_imp not in t:
        raise SystemExit("buscador import missing")
    t = t.replace(old_imp, new_imp, 1)

    old = """    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }"""
    new = """    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    if (!mounted) return;
    await PostContactoSheet.show(
      context,
      prestadorUid: prestadorUid,
      prestadorNombre: nombreLog.isEmpty ? null : nombreLog,
      desdeTarjeta: false,
      onPrimary: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TarjetaDigitalWidget(
              usuarioRef: db.collection('usuarios').doc(prestadorUid),
            ),
          ),
        );
      },
    );
  }"""
    if old not in t:
        raise SystemExit("buscador launchUrl block missing")
    t = t.replace(old, new, 1)
    t = t.replace(
        "/// UX 5.2 + 5.7: foto en fila, chip Cerca, empty state con salida.",
        "/// UX 5.2 + 5.7 + 5.8: post-WhatsApp explica comprobante.",
        1,
    )
    if t.count("{") != t.count("}"):
        raise SystemExit(f"buscador braces {t.count('{')} {t.count('}')}")
    p.write_text(t)
    print("buscador patched")


def patch_tarjeta():
    p = Path("lib/tarjetaDigital.dart")
    t = p.read_text()
    if "post_contacto_sheet.dart" in t:
        print("tarjeta already patched")
        return
    old_imp = "import 'contacto_service.dart';\n"
    new_imp = (
        "import 'contacto_service.dart';\n"
        "import 'contacto/post_contacto_sheet.dart';\n"
    )
    if old_imp not in t:
        raise SystemExit("tarjeta import missing")
    t = t.replace(old_imp, new_imp, 1)

    old_wa = """    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    else _alerta('No se pudo abrir WhatsApp');
  }"""
    new_wa = """    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    else _alerta('No se pudo abrir WhatsApp');
    if (!mounted) return;
    await PostContactoSheet.show(
      context,
      prestadorUid: prestadorUid,
      prestadorNombre: nombre.isEmpty ? null : nombre,
      desdeTarjeta: true,
      onPrimary: () => _emitirRecibo(prestadorUid, nombre),
    );
  }"""
    if old_wa not in t:
        raise SystemExit("tarjeta whatsapp block missing")
    t = t.replace(old_wa, new_wa, 1)

    old_call = """    if (await canLaunchUrl(url)) await launchUrl(url);
    else _alerta('No se pudo iniciar la llamada');
  }"""
    new_call = """    if (await canLaunchUrl(url)) await launchUrl(url);
    else _alerta('No se pudo iniciar la llamada');
    if (!mounted) return;
    await PostContactoSheet.show(
      context,
      prestadorUid: prestadorUid,
      prestadorNombre: prestadorNombre,
      desdeTarjeta: true,
      onPrimary: () => _emitirRecibo(prestadorUid, prestadorNombre ?? ''),
    );
  }"""
    if old_call not in t:
        raise SystemExit("tarjeta call block missing")
    t = t.replace(old_call, new_call, 1)

    if t.count("{") != t.count("}"):
        raise SystemExit(f"tarjeta braces {t.count('{')} {t.count('}')}")
    p.write_text(t)
    print("tarjeta patched")


if __name__ == "__main__":
    patch_buscador()
    patch_tarjeta()
