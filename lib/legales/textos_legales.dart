import '../geo/country_profile.dart';
import '../user_session.dart';

/// Textos legales PUELO — alineados a https://puelo.app/legales.html
/// Pack publicado para AR/CL/UY. Vigencia 2 de septiembre de 2026.
class TextosLegales {
  static const String vigencia = '2 de septiembre de 2026';
  static const String packPublicado = 'ar';

  static String packId([String? iso]) =>
      CountryProfile.of(iso ?? UserSession().countryCode).legalPack;

  static bool packReady([String? iso]) =>
      CountryProfile.isLaunch(iso ?? UserSession().countryCode);

  /// Vacío en AR/CL/UY. En el resto avisa que el pack local no está publicado.
  static String packNota([String? iso]) {
    if (packReady(iso)) return '';
    final name = CountryProfile.of(iso ?? UserSession().countryCode).name;
    return 'Estos documentos rigen el uso actual en Argentina, Chile y Uruguay. '
        'El pack de $name se publica cuando el servicio esté activo en ese país.';
  }

  static const String terminosTitulo = 'Términos y Condiciones';
  static const String terminosBajada =
      'Uso de la app, gratuidad y reglas de la comunidad.';

  static const String privacidadTitulo = 'Privacidad e identidad';
  static const String privacidadBajada =
      'Qué datos usamos, qué ve la comunidad y cómo ejercer tus derechos.';

  static const String buenasTitulo = 'Buenas prácticas';
  static const String buenasBajada =
      'Cómo nos tratamos para que la red de confianza funcione.';

  static const String csaeTitulo =
      'Protección contra la explotación y el abuso sexual infantil';
  static const String csaeBajada =
      'Política de tolerancia cero. Requerida para publicar en Google Play y App Store.';

  static const String checkboxAcepto =
      'Leí y acepto los Términos y Condiciones, la Política de Privacidad, '
      'el Reglamento de Buenas Prácticas y la política de protección infantil de PUELO.';

  static const String checkboxMicro =
      'Hoy el acceso es gratis. Tu documento y tu domicilio exacto no se '
      'publican en la comunidad.';

  static const String pieLegal =
      'Documentos publicados para la app y las tiendas (vigencia 02/09/2026). '
      'Describen el uso actual de PUELO como red de servicios. '
      'No son un dictamen legal externo.';

  static const List<LegalSection> terminos = [
    LegalSection(
      title: 'Qué es PUELO',
      body:
          'PUELO (también identificada en tiendas y en la app como PROX by Puelo.app) '
          'es una red digital de trabajo y de servicios. Te ayuda a mostrar lo que '
          'hacés, a encontrar quién puede ayudarte y a construir confianza con otras '
          'personas de la comunidad. PUELO no es un banco, no es una financiera y no '
          'es tu empleador. El acuerdo de cada trabajo lo cierran las personas entre sí.\n\n'
          'Hoy la app está disponible en Uruguay, Chile y Argentina. Podemos ampliar '
          'o limitar países más adelante, avisándolo en la app o en este sitio.',
    ),
    LegalSection(
      title: 'La app sale sin costo',
      body:
          'Publicamos la app en Google Play y App Store sin costo de descarga. '
          'Usar las funciones principales —crear cuenta, armar perfil, buscar, '
          'mostrar tu trabajo y contactar— no tiene cargo hoy.\n\n'
          'Mantener la plataforma tiene un costo. En el futuro podemos incorporar '
          'funciones opcionales de pago, planes o comisiones sobre servicios nuevos. '
          'Si eso ocurre, te lo vamos a informar con claridad y con anticipación '
          'dentro de la app y, cuando corresponda, en las tiendas. No te vamos a '
          'cobrar por sorpresa. Vas a poder aceptar las nuevas condiciones, seguir '
          'usando lo que continúe siendo gratuito o dejar de usar PUELO. Dejar de '
          'usarla no tiene costo de salida en esta etapa.\n\n'
          'Cualquier cobro futuro se hará respetando las normas de defensa del '
          'consumidor del país donde uses el servicio y las reglas de Google Play '
          'y App Store. Si hay una compra dentro de la app, se procesará por los '
          'sistemas de la tienda correspondiente.',
    ),
    LegalSection(
      title: 'Qué te pedimos',
      body:
          '• Tener 18 años o más. PUELO no está dirigida a menores.\n'
          '• Dar información verdadera en tu perfil y en cualquier validación.\n'
          '• Usar la app para servicios reales, no para suplantar identidades ni '
          'engañar a la comunidad.\n'
          '• Respetar estas condiciones, las Buenas prácticas y la política de '
          'protección infantil.\n'
          '• Entender que recomendaciones, distintivos de confianza y lo que se ve '
          'en tu perfil son señales de esta red, no una garantía de trabajo ni de ingreso.',
    ),
    LegalSection(
      title: 'Cuentas, contenido y tiendas',
      body:
          'Podés dejar de usar PUELO y pedir la baja de tu cuenta cuando quieras, '
          'escribiendo a infoprox@puelo.app o desde las opciones de la app, cuando '
          'estén disponibles.\n\n'
          'Si incumplís estas condiciones, las buenas prácticas, la política de '
          'protección infantil o la ley, podemos limitar funciones, ocultar contenido, '
          'ocultar el perfil o dar de baja la cuenta. Los casos graves (fraude, '
          'identidad falsa, abuso o contenido prohibido) pueden implicar baja inmediata.\n\n'
          'Google LLC y Apple Inc. no son parte de este acuerdo. La descarga y el uso '
          'también quedan sujetos a las condiciones de Google Play y de App Store que '
          'te correspondan.\n\n'
          'Te otorgamos una licencia limitada, revocable y no exclusiva para usar la '
          'app en tus dispositivos. El software, la marca y los contenidos de PUELO '
          'siguen siendo de Puelo.app o de sus licenciantes. El contenido que vos subís '
          '(fotos de trabajos, textos, recomendaciones) lo podés retirar; nos das '
          'permiso para mostrarlo en la red mientras tu cuenta esté activa, con el '
          'fin de operar el servicio.',
    ),
    LegalSection(
      title: 'Qué no prometemos',
      body:
          'PUELO no garantiza clientes, ingresos ni un resultado. No es parte del '
          'contrato de cada servicio, salvo cuando la ley lo exija o una función '
          'específica de la app lo indique con claridad (por ejemplo, un comprobante '
          'entre dos personas).',
    ),
    LegalSection(
      title: 'Cambios',
      body:
          'Si modificamos estos términos, los publicamos en la app y en '
          'puelo.app/legales.html con fecha de vigencia. Los cambios que afecten el '
          'precio o la gratuidad se avisarán con la anticipación que exija la '
          'normativa de consumidores aplicable. Seguir usando la app después de esa '
          'fecha implica aceptar el cambio, salvo que la ley de tu país disponga otra cosa.',
    ),
    LegalSection(
      title: 'Ley aplicable',
      body:
          'Estos términos se interpretan de forma compatible con las leyes de '
          'protección al consumidor y demás normas imperativas del país donde uses '
          'el servicio. Para controversias de consumo, serán competentes los '
          'tribunales o mecanismos que esa normativa asigne al domicilio del usuario. '
          'Nada de este texto reduce derechos irrenunciables que te reconozca la ley '
          'de tu país.',
    ),
  ];

  static const List<LegalSection> privacidad = [
    LegalSection(
      title: 'Marco',
      body:
          'Tratamos tu información personal según las leyes de protección de datos '
          'aplicables en el país donde uses PUELO. Eso incluye, cuando correspondan, '
          'las normas de Argentina, Chile y Uruguay, y cualquier otra que resulte '
          'obligatoria. Recogemos lo necesario para operar la app, validar que sos '
          'una persona real, sostener una red de confianza y prestar las funciones '
          'del ecosistema PUELO.\n\n'
          'Responsable del tratamiento: Puelo.app. Contacto: infoprox@puelo.app.',
    ),
    LegalSection(
      title: 'Para qué pedimos datos',
      body:
          '• Crear y mantener tu cuenta, autenticarte y permitirte recuperar el acceso.\n'
          '• Mostrar tu perfil profesional a quien busca un servicio (nombre, oficio, '
          'zona de trabajo, foto que elijas, trabajos que publiques, distintivos de '
          'confianza y recomendaciones).\n'
          '• Validar que tu identidad es real, para cuidar a la comunidad de perfiles '
          'falsos y respaldar distintivos de confianza.\n'
          '• Permitir que te contacten por los canales que habilites y registrar que '
          'ese contacto existió.\n'
          '• Mostrar comprobantes y mensajes entre vos y otra persona de la red.\n'
          '• Mejorar calidad, seguridad y prevención de abuso, y desarrollar funciones '
          'del ecosistema.\n'
          '• Cumplir obligaciones legales o requerimientos de una autoridad competente.\n'
          '• Atender reportes de seguridad, incluida la protección de niñas, niños y adolescentes.',
    ),
    LegalSection(
      title: 'Qué ve la comunidad y qué no',
      body:
          '• Nombre, oficio, foto de perfil y zona de trabajo (barrio / localidad, '
          'no la calle): sí, si publicás perfil. Para que te encuentren y te reconozcan.\n'
          '• Distintivos de confianza, recomendaciones y fotos de trabajos que subís: '
          'sí. Calidad de servicio en la red.\n'
          '• Teléfono / WhatsApp: solo si lo habilitás para contacto.\n'
          '• Domicilio personal exacto: no se publica en la comunidad.\n'
          '• Número de documento y fotos del documento: no se publican en tarjeta, '
          'buscador ni perfil visible.\n'
          '• Notas internas de validación: no como expediente; la comunidad ve '
          'distintivos y recomendaciones.',
    ),
    LegalSection(
      title: 'Validación de identidad',
      body:
          'Podemos pedir documento de identidad, fotos del documento y domicilio '
          'para confirmar que el perfil corresponde a una persona real. Esa '
          'información sensible tiene acceso restringido. No se publica en la '
          'tarjeta ni se lista en el buscador.',
    ),
    LegalSection(
      title: 'Qué no hacemos',
      body:
          '• No vendemos tu información personal.\n'
          '• No publicamos tu documento, las fotos de tu documento ni tu domicilio '
          'exacto en la comunidad ni en tu perfil visible.',
    ),
    LegalSection(
      title: 'Proveedores técnicos y tiendas',
      body:
          'Usamos infraestructura tecnológica (alojamiento, autenticación, '
          'almacenamiento de fotos, analítica básica de fallos si está activa) y '
          'los servicios de Google Play y App Store para publicar la app. Esos '
          'proveedores tratan datos como encargados o según sus propias políticas '
          'cuando vos interactuás con la tienda. Donde la ley lo exige, esa relación '
          'queda documentada.',
    ),
    LegalSection(
      title: 'Tus derechos',
      body:
          'Podés pedir acceso, rectificación, actualización, supresión, oposición o '
          'limitación, y ejercer los demás derechos que te reconozca la ley de tu '
          'país. Escribí a infoprox@puelo.app con el asunto “Datos personales”. '
          'También podés acudir a la autoridad de protección de datos de tu país.\n\n'
          'Si pedís la baja de la cuenta, dejamos de mostrar tu perfil en la '
          'comunidad. Podemos conservar el mínimo indispensable si una ley o un '
          'reclamo en curso lo exige, y solo por el tiempo necesario.',
    ),
    LegalSection(
      title: 'Conservación, seguridad y menores',
      body:
          'Guardamos los datos mientras tu cuenta esté activa y el tiempo extra que '
          'imponga una obligación legal. Aplicamos medidas razonables de acceso '
          'restringido, en especial sobre documentos de identidad y domicilio exacto.\n\n'
          'PUELO no está dirigida a menores de 18 años. No recopilamos de forma '
          'consciente datos de menores. Si detectamos una cuenta de un menor, la cerramos.',
    ),
  ];

  static const List<LegalSection> buenasPracticas = [
    LegalSection(
      title: 'El pilar',
      body:
          'PUELO es, antes que una herramienta, una red de trabajo. La tecnología '
          'no genera por sí sola un buen servicio: lo genera la confianza entre '
          'personas. Estas prácticas son condición para estar en la comunidad.',
    ),
    LegalSection(
      title: 'Lo que esperamos de todos',
      body:
          '• Cumplir lo acordado: horario, alcance del trabajo y forma de pago '
          'que hayan conversado.\n'
          '• Hablar con respeto en mensajes, llamadas y encuentros coordinados '
          'desde la app.\n'
          '• Dejar recomendaciones honestas, basadas en un servicio real.\n'
          '• Usar datos verdaderos. La validación de identidad no se fabrica ni '
          'se presta.\n'
          '• No hostigar, no discriminar, no presionar, no publicar datos privados '
          'de terceros.\n'
          '• Si algo sale mal, decirlo a tiempo.',
    ),
    LegalSection(
      title: 'Cómo se construye la confianza',
      body:
          'La confianza de la comunidad se arma con hechos de esta red: perfil '
          'completo, identidad validada, servicios publicados, recomendaciones de '
          'quienes realmente trabajaron con vos y el trato que sostenés. Eso se '
          'refleja en distintivos y en cómo te encuentran otras personas. Tu '
          'comportamiento define tus oportunidades.',
    ),
    LegalSection(
      title: 'Qué no se tolera',
      body:
          'El incumplimiento grave o reiterado, el fraude en validaciones, las '
          'recomendaciones falsas, el acoso, el perfil impersonado, el contenido '
          'sexual que involucre a menores y cualquier trato vejatorio pueden hacer '
          'que limitemos tu visibilidad, retiremos distintivos o excluamos la '
          'cuenta. En casos graves, la exclusión puede ser definitiva.',
    ),
    LegalSection(
      title: 'Reclamos entre personas',
      body:
          'Si hay un desacuerdo sobre un trabajo, primero corresponde resolverlo '
          'entre quienes lo acordaron. PUELO puede ayudar a ordenar la conversación '
          'o a revisar un abuso de la plataforma. No reemplaza a un perito, a la '
          'justicia ni a un mediador obligatorio, salvo que una función específica '
          'lo indique.',
    ),
  ];

  static const List<LegalSection> csae = [
    LegalSection(
      title: 'Tolerancia cero',
      body:
          'PUELO tiene tolerancia cero frente a la explotación y el abuso sexual '
          'infantil, incluido cualquier material de abuso sexual infantil (real, '
          'dibujado o generado por inteligencia artificial) y cualquier intento de '
          'captación o contacto inapropiado con menores.',
    ),
    LegalSection(
      title: 'Reglas',
      body:
          '• La app es solo para personas de 18 años o más.\n'
          '• Está prohibido crear, subir, guardar, enviar o pedir ese tipo de contenido.\n'
          '• Está prohibido usar la app para contactar, hostigar o explotar a un menor.',
    ),
    LegalSection(
      title: 'Cómo denunciar',
      body:
          'Si ves o sospechás algo, escribinos a infoprox@puelo.app con el asunto '
          '“Denuncia protección infantil”. También podés usar los canales de reporte '
          'de Google Play o App Store.\n\n'
          'Ante un hallazgo creíble podemos retirar el contenido, suspender o cerrar '
          'la cuenta y, cuando la ley lo exija o el caso lo amerite, informar a las '
          'autoridades competentes.',
    ),
  ];
}

class LegalSection {
  final String title;
  final String body;
  const LegalSection({required this.title, required this.body});
}

enum TipoDocumentoLegal { terminos, privacidad, buenasPracticas, csae }
