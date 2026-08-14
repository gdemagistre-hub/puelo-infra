import '../models/leccion.dart';

/// Audios publicados en Hosting de Finanzas (siguen online).
/// Cuando apaguemos ese proyecto, el CI ya copia los MP3 a lifewalletpuelo.
const _audioBase =
    'https://puelo-finanzas.web.app/content/academia/audio';

/// Cápsulas de educación financiera (migradas desde puelo-finanzas).
const catalogoLecciones = <Leccion>[
  Leccion(
    id: 'ahorro_inflacion',
    titulo: 'Ahorrar sin que la inflación te coma la plata',
    resumen: 'Juntar billetes abajo del colchón pierde valor. Opciones simples.',
    minutos: 4,
    tag: 'Ahorro',
    audioUrl: '$_audioBase/ahorro_inflacion.mp3',
    cuerpo: '''
En Argentina, si dejás la plata quieta en efectivo meses, con el tiempo compra menos. Eso es la inflación.

No hace falta ser experto. Ideas de oficio:

1. Apartá apenas cobrás
No esperes a fin de mes. De cada cobro, separá un porcentaje chico para tu meta (vacaciones, herramienta, emergencia).

2. La meta en la app es un recordatorio
Cuando apartás, esa plata deja de estar en "disponible". Así no la gastás sin darte cuenta.

3. No dejes todo en billetes
Si vas a juntar varios meses:
- Considerá instrumentos simples en pesos que ajusten (según lo que te recomiende alguien de confianza o tu banco).
- O convertí parte a algo que no se licúe tan rápido, si te resulta práctico.
- Si la meta es una herramienta, a veces conviene comprar antes de que suba de precio.

4. Regla práctica
Primero: anotar cobros y gastos.
Segundo: apartar a la meta.
Tercero: pensar dónde parkear esa plata si el objetivo es lejano.

Apartar no es perder: es decidir que esa plata tiene un destino, antes de que se evapore en gastos chicos o en inflación.
''',
  ),
  Leccion(
    id: 'separar_plata',
    titulo: 'Separá la plata del trabajo',
    resumen: 'No mezcles lo que cobrás con lo de la casa.',
    minutos: 3,
    tag: 'Básico',
    audioUrl: '$_audioBase/separar_plata.mp3',
    cuerpo: '''
Cuando cobrás un trabajo, esa plata no es toda "tuya para gastar".

Una forma simple:
1. Anotá el cobro en la app.
2. Restá materiales y viajes.
3. Lo que sobra es la plata que te quedó.
4. De eso, apartá una parte a una meta.

Si mezclás todo en el bolsillo, a fin de mes no sabés si ganaste o perdiste.
''',
  ),
  Leccion(
    id: 'presupuesto_obra',
    titulo: 'Cómo no perder plata en un presupuesto',
    resumen: 'Materiales + tiempo + un colchón.',
    minutos: 4,
    tag: 'Obra',
    audioUrl: '$_audioBase/presupuesto_obra.mp3',
    cuerpo: '''
Antes de decir un precio, pensá en 3 cosas:

1. Materiales (con un poco de más por si falta algo).
2. Tu tiempo (horas × lo que vale tu hora).
3. Un colchón del 10–15% por imprevistos.

Si solo cobrás "lo que el cliente quiere pagar", a veces trabajás gratis sin darte cuenta.

Tip: anotá en Gasté cada compra de la obra. Así ves si el trabajo te dejó plata de verdad.
''',
  ),
  Leccion(
    id: 'herramientas',
    titulo: 'Juntá para tu próxima herramienta',
    resumen: 'Una meta chica cada semana.',
    minutos: 2,
    tag: 'Ahorro',
    audioUrl: '$_audioBase/herramientas.mp3',
    cuerpo: '''
En vez de pensar "necesito 300 lucas de una", pensá:

"Si guardo un poco de cada trabajo, en X semanas llego."

Ejemplo:
- Querés un taladro de 150.000
- Apartás 15.000 por semana a la meta
- En 10 semanas lo tenés

Usá Mis números para anotar y Metas para reservar esa plata.
''',
  ),
  Leccion(
    id: 'gastos_escondidos',
    titulo: 'Los gastos que no se ven',
    resumen: 'Nafta, comida en la obra, desgaste.',
    minutos: 3,
    tag: 'Gastos',
    audioUrl: '$_audioBase/gastos_escondidos.mp3',
    cuerpo: '''
Muchos oficios pierden plata en cosas chicas:

- Nafta / colectivo / Uber a la obra
- Almuerzo afuera
- Cinta, tornillos, "unos pesos más" en el corralón
- Herramienta que se rompe

Si no los anotá, parece que cobraste bien… pero te quedó poco.

Usá el botón Gasté con categorías. En una semana vas a ver el patrón.
''',
  ),
  Leccion(
    id: 'cobrar_bien',
    titulo: 'Cobrá una seña',
    resumen: 'No empieces sin algo por delante.',
    minutos: 2,
    tag: 'Cobros',
    audioUrl: '$_audioBase/cobrar_bien.mp3',
    cuerpo: '''
Pedir seña no es de malo: es cuidarte.

Sirve para:
- Comprar materiales sin poner plata de tu bolsillo
- Que el cliente se comprometa
- No quedar colgado si cancelan

Una regla simple: seña para materiales + algo de tu tiempo reservado.

Anotá la seña como Cobré el día que la recibís.
''',
  ),
];
