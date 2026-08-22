/// Textos legales PUELO — versión producto 2026-08-22.
/// Confianza / calidad de servicio / red. Sin scoring ni cesión externa.
class TextosLegales {
  static const String vigencia = '22 de agosto de 2026';

  static const String terminosTitulo = 'Términos y Condiciones';
  static const String terminosBajada =
      'Cómo se usa PUELO hoy y cómo te avisamos si el servicio cambia.';

  static const String privacidadTitulo = 'Privacidad e identidad';
  static const String privacidadBajada =
      'Qué datos usamos, qué ve la comunidad y qué nunca sale de PUELO.';

  static const String buenasTitulo = 'Buenas prácticas';
  static const String buenasBajada =
      'Cómo nos tratamos para que la red de confianza funcione.';

  static const String checkboxAcepto =
      'Leí y acepto los Términos y Condiciones, la Política de Privacidad '
      'y el Reglamento de Buenas Prácticas de PUELO.';

  static const String checkboxMicro =
      'Hoy el acceso es gratis. Tu documento y tu domicilio exacto no se '
      'publican. La confianza que construís se usa solo dentro de PUELO.';

  /// Cuerpo completo de Términos (secciones).
  static const List<LegalSection> terminos = [
    LegalSection(
      title: 'Qué es PUELO',
      body:
          'PUELO es una red digital de trabajo y de servicios. Te ayuda a mostrar '
          'lo que hacés, a encontrar quién puede ayudarte y a construir confianza '
          'con otras personas de la comunidad. PUELO no es un banco, no es una '
          'financiera y no es tu empleador. El acuerdo de cada trabajo lo cierran '
          'las personas entre sí.',
    ),
    LegalSection(
      title: 'Acceso en esta etapa',
      body:
          'Hoy el acceso a las herramientas principales de PUELO es gratuito. '
          'El objetivo de esta etapa es que puedas armar tu presencia, digitalizar '
          'la gestión de tus servicios y participar de la red de confianza sin una '
          'barrera de entrada económica.\n\n'
          'Crear y mantener la plataforma tiene un costo. Por eso nos reservamos '
          'la posibilidad de incorporar, más adelante, planes pagos, cargos por '
          'herramientas nuevas o comisiones sobre servicios que todavía no existen '
          'en la app.',
    ),
    LegalSection(
      title: 'Si en el futuro deja de ser gratis',
      body:
          'Cualquier cambio que altere la gratuidad actual se hará en el marco de '
          'la Ley de Defensa del Consumidor (Ley 24.240). Vas a ser notificado con '
          'la anticipación que corresponda. No te vamos a cobrar por sorpresa.\n\n'
          'Cuando llegue ese momento, vas a poder aceptar las nuevas condiciones o '
          'dejar de usar PUELO. Seguir usando la app después de la fecha que '
          'indiquemos en el aviso implica aceptar el cambio. Dejar de usarla no '
          'tiene costo de salida en esta etapa.',
    ),
    LegalSection(
      title: 'Qué te pedimos para usar la app',
      body:
          '• Tener 18 años o más.\n'
          '• Dar información verdadera cuando completes tu perfil o una validación.\n'
          '• Usar la app para servicios reales, no para suplantar identidades ni '
          'engañar a la comunidad.\n'
          '• Respetar el Reglamento de Buenas Prácticas.\n'
          '• Entender que las recomendaciones, los distintivos de confianza y lo '
          'que se ve en tu perfil son parte de esta red y no una garantía de trabajo.',
    ),
    LegalSection(
      title: 'Qué no prometemos',
      body:
          'PUELO no garantiza una cantidad de clientes, un ingreso ni un resultado. '
          'Tampoco interviene como parte del contrato de cada servicio, salvo cuando '
          'la ley lo exija o cuando una función específica de la app lo indique con '
          'claridad (por ejemplo, un comprobante entre dos personas).',
    ),
    LegalSection(
      title: 'Cuentas, suspensión y baja',
      body:
          'Podés dejar de usar PUELO cuando quieras. Si incumplís estos términos, '
          'el Reglamento de Buenas Prácticas o la ley, podemos limitar funciones, '
          'ocultar el perfil o dar de baja la cuenta, con el aviso que resulte '
          'razonable según la gravedad. Los casos de fraude, identidad falsa o '
          'abuso grave pueden implicar baja inmediata para proteger a la comunidad.',
    ),
    LegalSection(
      title: 'Cambios de estos términos',
      body:
          'Si modificamos estos términos, lo vamos a publicar en la app con fecha '
          'de vigencia. Los cambios que no afecten el precio se comunicarán de '
          'forma visible. Los que sí afecten el precio o la gratuidad siguen la '
          'regla de aviso de la Ley 24.240.',
    ),
    LegalSection(
      title: 'Ley aplicable',
      body:
          'Estos términos se rigen por las leyes de la República Argentina. Para '
          'cualquier controversia, serán competentes los tribunales ordinarios del '
          'domicilio del usuario en los términos de la normativa de defensa del '
          'consumidor, cuando ésta resulte aplicable.',
    ),
  ];

  static const List<LegalSection> privacidad = [
    LegalSection(
      title: 'Marco',
      body:
          'El tratamiento de tu información personal se rige por la Ley de '
          'Protección de los Datos Personales (Ley 25.326) y normas complementarias '
          'de la República Argentina. Recogemos solo lo necesario para operar la '
          'app, validar que sos una persona real y sostener una red de confianza '
          'entre quienes buscan y quienes ofrecen un servicio.',
    ),
    LegalSection(
      title: 'Compromiso de finalidad',
      body:
          'Lo que registramos sobre tu identidad y sobre cómo te relacionás en '
          'PUELO se usa dentro de PUELO. No lo entregamos a terceros para que te '
          'evalúen, no lo usamos para armar un perfil fuera de esta comunidad y no '
          'lo comercializamos. La confianza que construís acá se queda acá.',
    ),
    LegalSection(
      title: 'Para qué pedimos datos',
      body:
          'Usamos tu información para estas finalidades, y no para otras '
          'incompatibles:\n\n'
          '• Crear y mantener tu cuenta.\n'
          '• Mostrar tu perfil profesional a quien busca un servicio (nombre, '
          'oficio, zona de trabajo, foto que vos elijas, trabajos que vos '
          'publiques, distintivos de confianza y recomendaciones).\n'
          '• Validar internamente que tu identidad es real, para cuidar a la '
          'comunidad de perfiles falsos y respaldar los distintivos de confianza.\n'
          '• Permitir que te contacten por los canales que habilites y registrar '
          'que ese contacto existió.\n'
          '• Mostrar comprobantes y mensajes entre vos y otra persona de la red.\n'
          '• Mejorar la calidad del servicio de la app (errores, seguridad, '
          'prevención de abuso).\n'
          '• Cumplir obligaciones legales si una autoridad competente lo requiere.',
    ),
    LegalSection(
      title: 'Qué ve la comunidad y qué no',
      body:
          '• Nombre, oficio, foto de perfil y zona de trabajo (barrio / localidad, '
          'no la calle): sí, si publicás perfil.\n'
          '• Distintivos de confianza, recomendaciones y fotos de trabajos que '
          'subís: sí.\n'
          '• Teléfono / WhatsApp: solo si vos lo habilitás para contacto.\n'
          '• Domicilio personal exacto (calle y número): no.\n'
          '• Número de DNI y fotos del documento: no. Jamás se publican ni se '
          'comparten con otros usuarios.\n'
          '• Notas internas de validación: no como expediente; solo se refleja lo '
          'que la app muestra (distintivo, recomendaciones).',
    ),
    LegalSection(
      title: 'Validación de identidad',
      body:
          'Te podemos pedir DNI, fotos del documento y domicilio para confirmar '
          'que el perfil corresponde a una persona real. Esa información sensible '
          'queda aislada. No se publica en la tarjeta, no se lista en el buscador '
          'y no se entrega a otros usuarios ni a otras aplicaciones, estén o no '
          'ligadas al mismo grupo.\n\n'
          'La pedimos solo para respaldar tu reputación dentro de PUELO, emitir '
          'distintivos de confianza y proteger a la comunidad de perfiles falsos.',
    ),
    LegalSection(
      title: 'Qué no hacemos',
      body:
          '• No vendemos tu información personal.\n'
          '• No entregamos tu DNI, tus fotos de documento ni tu domicilio exacto '
          'a otras personas ni a otras plataformas.\n'
          '• No usamos tu actividad en PUELO para armarte un perfil de confianza '
          'fuera de esta app.\n'
          '• No cedemos tu reputación de la red para que un tercero decida sobre vos.',
    ),
    LegalSection(
      title: 'Proveedores técnicos',
      body:
          'Para que la app funcione usamos infraestructura tecnológica '
          '(alojamiento, autenticación, almacenamiento de fotos). Esos proveedores '
          'tratan datos como encargados, para operar el servicio, no para usarlos '
          'con una finalidad propia sobre tu reputación.',
    ),
    LegalSection(
      title: 'Tus derechos',
      body:
          'Podés pedir acceso, rectificación, actualización o supresión de tus '
          'datos personales, y ejercer los demás derechos que reconoce la Ley '
          '25.326. Escribí a privacidad@puelo.cloud (canal provisorio de producto). '
          'También podés plantear un reclamo ante la Agencia de Acceso a la '
          'Información Pública.\n\n'
          'Si pedís la baja de la cuenta, dejamos de usar tu perfil en la '
          'comunidad. Podemos conservar el mínimo indispensable si una ley o un '
          'reclamo en curso lo exige, y solo por el tiempo necesario.',
    ),
    LegalSection(
      title: 'Conservación y seguridad',
      body:
          'Guardamos los datos mientras tu cuenta esté activa y el tiempo extra '
          'que imponga una obligación legal. Aplicamos medidas razonables de '
          'acceso restringido, en especial sobre documentos de identidad y '
          'domicilio exacto.',
    ),
  ];

  static const List<LegalSection> buenasPracticas = [
    LegalSection(
      title: 'El pilar',
      body:
          'PUELO es, antes que una herramienta, una red de trabajo. La tecnología '
          'no genera por sí sola un buen servicio: lo genera la confianza entre '
          'personas. Por eso estas prácticas no son un consejo. Son condición para '
          'estar en la comunidad.',
    ),
    LegalSection(
      title: 'Lo que esperamos de todos',
      body:
          '• Cumplir lo acordado: horario, alcance del trabajo y forma de pago '
          'que hayan conversado.\n'
          '• Hablar con respeto en mensajes, llamadas y encuentros coordinados '
          'desde la app.\n'
          '• Dejar recomendaciones honestas, basadas en un servicio real. Ni '
          'inflar ni hundir a alguien por un motivo ajeno al trabajo.\n'
          '• Usar datos verdaderos. La validación de identidad no se fabrica ni '
          'se presta.\n'
          '• Cuidar a la otra persona: no hostigar, no discriminar, no presionar, '
          'no publicar datos privados de terceros.\n'
          '• Si algo sale mal, decirlo a tiempo. Una demora avisada no es lo '
          'mismo que desaparecer.',
    ),
    LegalSection(
      title: 'Cómo se construye la confianza acá',
      body:
          'En PUELO, la confianza de la comunidad se arma con hechos de esta red: '
          'perfil completo, identidad validada, servicios publicados, '
          'recomendaciones de quienes realmente trabajaron con vos y el trato que '
          'sostenés. Eso se refleja en distintivos y en cómo te encuentran otras '
          'personas dentro de PUELO.\n\n'
          'Esa confianza no se exporta. No es una calificación para afuera ni un '
          'antecedente que entreguemos a nadie. Es el modo en que esta comunidad '
          'reconoce un buen servicio.',
    ),
    LegalSection(
      title: 'Qué no se tolera',
      body:
          'El incumplimiento grave o reiterado de lo acordado, el fraude en '
          'validaciones, las recomendaciones falsas, el acoso, el perfil '
          'impersonado y cualquier trato vejatorio pueden hacer que limitemos tu '
          'visibilidad, retiremos distintivos o excluamos la cuenta. En casos '
          'graves, la exclusión puede ser definitiva.',
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
}

class LegalSection {
  final String title;
  final String body;
  const LegalSection({required this.title, required this.body});
}

enum TipoDocumentoLegal { terminos, privacidad, buenasPracticas }
