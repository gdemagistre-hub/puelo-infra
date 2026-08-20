import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

/// Keys de Showcase anclados a widgets reales del Home.
class HomeTourKeys {
  HomeTourKeys._();

  static final menu = GlobalKey();
  static final roleToggle = GlobalKey();
  static final searchOrConfianza = GlobalKey();
  static final primaryBlock = GlobalKey();
  static final navMisNumeros = GlobalKey();
  static final navAcademia = GlobalKey();
}

/// Orden de pasos según rol.
List<GlobalKey> homeTourKeysFor({required bool modoPrestador}) {
  if (modoPrestador) {
    return [
      HomeTourKeys.menu,
      HomeTourKeys.roleToggle,
      HomeTourKeys.searchOrConfianza,
      HomeTourKeys.primaryBlock,
      HomeTourKeys.navMisNumeros,
      HomeTourKeys.navAcademia,
    ];
  }
  return [
    HomeTourKeys.menu,
    HomeTourKeys.searchOrConfianza,
    HomeTourKeys.primaryBlock,
    HomeTourKeys.navMisNumeros,
  ];
}

/// Tooltip corto, acción clara (estilo producto maduro).
class HomeTourCopy {
  final String title;
  final String description;

  const HomeTourCopy(this.title, this.description);

  static HomeTourCopy forKey(GlobalKey key, {required bool modoPrestador}) {
    if (key == HomeTourKeys.menu) {
      return const HomeTourCopy(
        'Tu menú',
        'Perfil, domicilio y preferencias. El domicilio ayuda a mostrar prestadores de tu zona.',
      );
    }
    if (key == HomeTourKeys.roleToggle) {
      return const HomeTourCopy(
        'Ofrezco / Busco',
        'Cambiá entre tu vista de prestador y la de cliente cuando uses ambos roles.',
      );
    }
    if (key == HomeTourKeys.searchOrConfianza) {
      if (modoPrestador) {
        return const HomeTourCopy(
          'Así te ven',
          'Nivel, estrellas y confianza: es lo que ven los clientes al encontrarte.',
        );
      }
      return const HomeTourCopy(
        'Buscá un servicio',
        'Escribí lo que necesitás o elegí un oficio. Te mostramos prestadores cercanos.',
      );
    }
    if (key == HomeTourKeys.primaryBlock) {
      if (modoPrestador) {
        return const HomeTourCopy(
          'Tu tarjeta digital',
          'Compartila por WhatsApp. Es tu presentación y el mismo perfil que aparece en búsquedas.',
        );
      }
      return const HomeTourCopy(
        'Más confianza',
        'Atajo a prestadores mejor evaluados cerca tuyo.',
      );
    }
    if (key == HomeTourKeys.navMisNumeros) {
      return const HomeTourCopy(
        'Mis números',
        'Tu dinero en privado: cobros, gastos y bolsillo. Protegido con PIN.',
      );
    }
    if (key == HomeTourKeys.navAcademia) {
      return const HomeTourCopy(
        'Academia',
        'Tips cortos de microfinanzas para el día a día del oficio.',
      );
    }
    return const HomeTourCopy('Puelo', 'Seguí explorando la app.');
  }
}

/// Envuelve un hijo con Showcase + copy del paso.
Widget homeShowcase({
  required GlobalKey key,
  required bool modoPrestador,
  required Color accent,
  required Widget child,
  TooltipPosition tooltipPosition = TooltipPosition.bottom,
}) {
  final copy = HomeTourCopy.forKey(key, modoPrestador: modoPrestador);
  return Showcase(
    key: key,
    title: copy.title,
    description: copy.description,
    targetBorderRadius: BorderRadius.circular(14),
    tooltipBackgroundColor: Colors.white,
    textColor: const Color(0xFF0F172A),
    titleTextStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w900,
      color: accent,
    ),
    descTextStyle: const TextStyle(
      fontSize: 13,
      height: 1.35,
      color: Color(0xFF475569),
    ),
    tooltipPadding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    tooltipBorderRadius: BorderRadius.circular(16),
    overlayColor: Colors.black,
    overlayOpacity: 0.62,
    tooltipPosition: tooltipPosition,
    child: child,
  );
}

/// Arranca el showcase (API 5.x).
void startHomeTourShowcase({
  required bool modoPrestador,
  Duration delay = const Duration(milliseconds: 400),
}) {
  final keys = homeTourKeysFor(modoPrestador: modoPrestador);
  try {
    ShowcaseView.get().startShowCase(keys, delay: delay);
  } catch (_) {
    // Si el registro aún no está listo, ignorar (retry vía Guía rápida).
  }
}
