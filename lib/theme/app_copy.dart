/// Copy oficial y glosario UI de PROX.
///
/// Premisa: solo ofrecer / contratar / evaluar / confiar.
/// Prohibido en UI: Life Wallet, Puelo, score crediticio, préstamos,
/// "gestión de trabajos" como título principal.
/// Backend / Firebase / Storage pueden seguir nombrando puelo.
class AppCopy {
  AppCopy._();

  // —— Marca (solo cara al usuario) ——
  static const String appName = 'PROX';

  /// Emails de soporte / contacto (cara al usuario).
  static const String emailInfo = 'info@puelo.app';
  static const String emailHelp = 'help@puelo.app';
  static const String emailProx = 'prox@puelo.app';

  // —— Promesa de valor (5 segundos) ——
  static const String promiseCliente =
      'Encontrá quien te hace el trabajo, con gente de confianza.';

  static const String promisePrestador =
      'Mostrá tu trabajo y conseguí clientes cerca.';

  static const String welcomeTitle = 'Te damos la bienvenida';

  static const String welcomeSubtitle =
      'Ofrecé o contratá servicios de oficio, evaluá y generá confianza.';

  // —— CTAs ——
  static const String ctaWhatsApp = 'Escribir por WhatsApp';
  static const String ctaLlamar = 'Llamar';
  static const String ctaBuscar = 'Buscar prestadores';
  static const String ctaCalificar = '¿Cómo te fue con el trabajo?';
  static const String ctaCompartirTarjeta = 'Compartir por WhatsApp';
  static const String ctaProximamente = 'Próximamente';

  // —— Navegación / secciones ——
  static const String navHome = 'Home';
  static const String navEvaluar = 'Evaluar';
  static const String navMensajes = 'Mensajes';
  static const String navPerfil = 'Perfil';

  static const String homeClienteHint = '¿Qué servicio necesitás?';
  static const String homePrestadorHint = '¿Qué vas a ofrecer hoy?';

  static const String seccionServiciosBuscados = 'Servicios más buscados';
  static const String seccionConsejos = 'Consejos para crecer';
  static const String seccionActividad = 'Tu actividad';

  /// Placeholder honesto (no inventar mensajes).
  static const String actividadVacia =
      'Acá vas a ver tu actividad cuando empieces a usar PROX.';

  // —— Confianza ——
  static const String badgeTapHint = 'Tocá para ver qué significa';
  static const String datoSensibleHint =
      'Para que otros confíen en que sos vos';
  static const String validacionTercerosHint =
      'Pedile a alguien que te conoce que confirme';

  // —— Errores / red ——
  static const String sinConexion =
      'No hay internet. Revisá los datos e intentá de nuevo.';
  static const String errorGenerico =
      'Algo salió mal. Probá de nuevo en unos segundos.';
  static const String sinPrestadoresZona =
      'No hay prestadores en esta zona. Probá ampliar la búsqueda.';

  // —— Glosario: textos PROHIBIDOS en UI de producto ——
  static const List<String> forbiddenUiTerms = [
    'Life Wallet',
    'lifewallet',
    'Puelo',
    'puelo',
    'score',
    'score_credito',
    'préstamo',
    'prestamo',
    'crédito bancario',
    'Gestión de Trabajos',
    'Modo Desarrollador',
  ];
}
