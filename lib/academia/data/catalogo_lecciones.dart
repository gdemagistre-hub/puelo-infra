import '../models/leccion.dart';

/// Audios servidos same-origin desde Hosting PROX.
/// Los MP3 viven en content/academia/audio/ del repo; el CI los copia a build/web.
const _audioBase =
    'https://lifewalletpuelo.web.app/content/academia/audio';

/// Cápsulas de educación financiera para el oficio.
/// Orden: Módulo 1 (Mis Números) → Módulo 2 (tips) → Módulo 3 (Metas + Vencimientos).
const catalogoLecciones = <Leccion>[
  // ─────────────────────────────────────────────
  // MÓDULO 1 — Control diario y semanal
  // ─────────────────────────────────────────────
  Leccion(
    id: 'cuanto_te_quedo',
    titulo: '¿Cuánto te quedó realmente hoy?',
    resumen: 'La cuenta que no miente. Cobré, Gasté y lo que sobra.',
    minutos: 4,
    tag: 'Básico',
    audioUrl: '$_audioBase/cuanto_te_quedo.mp3',
    cuerpo: '''
Terminás el día, tenés plata en la mano o en la cuenta y dan ganas de respirar aliviado. Sin embargo, hay una trampa muy común: la plata que cobrás no es toda tuya.

Si hacés fletes, arreglás autos, pintás o vendés comida, una parte importante de ese dinero tiene que volver a comprar materiales, pagar la nafta o reponer mercadería. Si te gastás todo lo que cobraste, mañana no tenés con qué arrancar.

La regla de los 3 botones

Desde Mis números cuidás las cuentas con tres toques:

1. Cobré (botón celeste): anotás cada trabajo o venta que te pagaron.

2. Gasté (botón rojo): cargás únicamente lo que pusiste para trabajar (repuestos, harina, pintura, combustible).

3. Me saqué (botón amarillo): anotás la plata que retirás de la caja para tus gastos personales o los de tu familia (comida, alquiler, súper).

Al final del día, mirás arriba en grande la Plata que quedó en el negocio. Si ese número está en verde y positivo, significa que tu trabajo cubre los gastos, te da de comer y además deja un resto para que el negocio siga en pie.

Hacelo ahora
Tocá el botón redondo del medio (Mis números). Cargá lo que cobraste hoy con Cobré y anotá lo que gastaste en materiales con Gasté. Mirá cómo cambia la plata que te queda disponible.
''',
  ),
  Leccion(
    id: 'sueldo_independiente',
    titulo: 'El sueldo del independiente',
    resumen: 'No fundas tu negocio por ir al súper. Tratate como un empleado.',
    minutos: 4,
    tag: 'Básico',
    audioUrl: '$_audioBase/sueldo_independiente.mp3',
    cuerpo: '''
Uno de los errores más comunes cuando trabajás por tu cuenta es pagar las compras diarias del hogar directamente con la plata que te acaban de pagar por un laburo. Parece lo más cómodo, pero mezclar los bolsillos hace que nunca sepas si el trabajo no rinde o si en casa se está gastando de más.

La forma de proteger tu trabajo es tratarte a vos mismo como a un empleado: asignate un retiro diario o semanal.

Cómo usar «Me saqué» a tu favor

En vez de meter la mano en la caja cada vez que necesitás comprar algo para la casa:

• Definí un monto fijo por día o por semana para tus gastos familiares.

• Cada vez que te pases plata a tu bolsillo personal, tocás el botón amarillo Me saqué.

• La app resta ese dinero de la caja del trabajo y te deja ver si tu actividad realmente puede bancar ese nivel de vida.

Si al mirar la pantalla ves que la Plata que quedó en el negocio termina en cero todos los días, la señal es clara: te estás sacando más de lo que el negocio genera. Ajustar ese retiro a tiempo te evita tener que salir a pedir préstamos caros para tapar agujeros.
''',
  ),
  Leccion(
    id: 'mirar_la_semana',
    titulo: 'Mirar la semana antes de pedir un préstamo',
    resumen: 'Un día bueno no alcanza. Mirá Semana y Mes antes de firmar.',
    minutos: 4,
    tag: 'Préstamos',
    audioUrl: '$_audioBase/mirar_la_semana.mp3',
    cuerpo: '''
Un día bueno lo tiene cualquiera, y un día malo también. Si hoy hiciste un trabajo grande y te quedaron varios cientos de miles limpios, podrías pensar que podés pagar cualquier cuota. Pero si los tres días siguientes no vendiste nada o llovió y no pudiste salir, la realidad cambia.

Por eso, antes de asumir un crédito, nunca tomes decisiones mirando solo lo que cobraste hoy.

El semáforo de tu mes

Arriba en Mis números tenés tres pestañas: Hoy, Semana y Mes.

• Semana: te muestra el promedio real de tus últimos días de laburo, balanceando los días flojos con los días pico.

• Mes: te da la foto completa de tus ingresos reales frente a todos tus costos y retiros.

¿Cómo saber si podés sacar un crédito?

Mirá el saldo de Plata que quedó en el negocio en la pestaña Mes:

• Si después de pagar materiales (Gasté) y de llevar plata a tu casa (Me saqué) te sobra con regularidad —por ejemplo, el equivalente a dos o tres cuotas—, sabés que una cuota moderada la pagás cómodo y sin sufrir.

• Si el saldo mensual queda muy justo o en cero, tomar una cuota nueva va a significar sacarle comida a tu casa o no poder reponer mercadería.

Revisalo ahora
Entrá a Mis números, cambiá la vista a Semana o Mes y fijate cuál es tu sobrante real antes de comprometerte con un pago nuevo.
''',
  ),
  Leccion(
    id: 'me_deben_fiados',
    titulo: 'Que no se te escape la plata',
    resumen: 'Cómo cobrar con «Me deben». La libreta de fiados en la app.',
    minutos: 3,
    tag: 'Cobros',
    audioUrl: '$_audioBase/me_deben_fiados.mp3',
    cuerpo: '''
Muchos trabajadores independientes y comerciantes barriales no están cortos de trabajo, sino cortos de efectivo porque tienen la plata parada en la calle. El fiado o el trabajo que se entrega «para cobrar el viernes» muchas veces se olvida, se estira o se cobra tarde.

Cuando prestás mercadería o hacés un laburo sin cobrar en el acto, te estás descapitalizando vos para financiar a otro.

Tu libreta de fiados en la app

Justo abajo de los botones de carga tenés la sección Me deben:

1. Tocás Anotar.

2. Ponés el nombre de la persona, el monto que te debe y qué le diste (por ejemplo: 50 litros de nafta o mano de obra revoque).

3. Elegís la fecha pactada de cobro.

Tener esto a la vista te permite saber cuánta plata tenés en la calle y recordarle al cliente su compromiso el día acordado.

Apenas la persona te paga, tocás Cobré al lado de su nombre: esa plata entra automáticamente a tus números del día.
''',
  ),

  // ─────────────────────────────────────────────
  // MÓDULO 2 — Tips de obra, ahorro y cobro
  // ─────────────────────────────────────────────
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
Cuando apartás, esa plata deja de estar en «disponible». Así no la gastás sin darte cuenta.

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
Cuando cobrás un trabajo, esa plata no es toda «tuya para gastar».

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

Si solo cobrás «lo que el cliente quiere pagar», a veces trabajás gratis sin darte cuenta.

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
En vez de pensar «necesito 300 lucas de una», pensá:

«Si guardo un poco de cada trabajo, en X semanas llego.»

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
- Cinta, tornillos, «unos pesos más» en el corralón
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
  Leccion(
    id: 'cuidado_con_prestamos',
    titulo: 'Antes de pedir un préstamo',
    resumen: 'Primero los números. Después la decisión.',
    minutos: 4,
    tag: 'Préstamos',
    audioUrl: '$_audioBase/cuidado_con_prestamos.mp3',
    cuerpo: '''
Un préstamo no es «plata fácil». Es una cuota que va a salir todos los meses, aunque el mes esté flojo.

Antes de firmar nada, mirá estas 4 cosas:

1. ¿Sabés cuánto te queda de verdad?
Si no anotás Cobré y Gasté, no sabés si el mes te sobra o te falta.
Sin números claros, cualquier cuota es un riesgo.

2. ¿Tenés un colchón?
Si mañana no hay trabajo una semana, ¿aguantás sin tocar la plata de la casa?
El fondo de emergencia (Metas → Colchón) es lo primero.
Si no tenés colchón, el préstamo te puede ahogar en el primer bache.

3. ¿La plata es para algo que genera más plata?
Herramienta que te permite hacer más trabajos o cobrar mejor: a veces sí tiene sentido.
Consumo, vacaciones o «porque me lo ofrecieron»: casi nunca.

4. ¿La cuota entra cómoda en tu mes normal?
No en el mejor mes. En un mes promedio.
Si para pagarla tenés que rezar, no estás en condiciones.

Regla simple de oficio:
Primero anotar. Después apartar. Después juntar para la herramienta.
El préstamo es el último recurso, no el primero.

Si llegás a esos 4 puntos con números claros en la app, ahí sí podés mirar opciones con más tranquilidad.
''',
  ),

  // ─────────────────────────────────────────────
  // MÓDULO 3 — Metas y vencimientos
  // ─────────────────────────────────────────────
  Leccion(
    id: 'colchon_antes_sueno',
    titulo: 'Primero el colchón, después el sueño',
    resumen: 'El fondo de emergencia antes de la meta linda.',
    minutos: 4,
    tag: 'Metas',
    audioUrl: '$_audioBase/colchon_antes_sueno.mp3',
    cuerpo: '''
Cuando arrancás a juntar plata, la tentación es ir de una a la meta linda: la herramienta nueva, las vacaciones, el local. El problema es que si no tenés un colchón, el primer bache te obliga a romper esa meta o a pedir plata cara.

En Metas hay dos tipos de cosas:

• Colchón (fondo de emergencia): plata para aguantar una semana o dos sin laburo, una rotura o un imprevisto. No es para gastar «porque sí».

• Metas aspiracionales: lo que querés construir o comprar (taladro, moto, curso, etc.).

La regla simple: primero armá un colchón chico. Después, con lo que sobra de cada semana, alimentá la meta del sueño.

Si usás «Usar» del colchón, es porque hubo un golpe real. Después, la prioridad vuelve a ser reponerlo.

Hacelo ahora
Entrá a Mis números → Metas. Si no tenés colchón, crealo con un monto chico pero realista. El resto de las metas pueden esperar un poco.
''',
  ),
  Leccion(
    id: 'meta_que_se_pueda_tocar',
    titulo: 'Una meta que se pueda tocar',
    resumen: 'Nombre, monto y ritmo. Sin eso no es meta.',
    minutos: 3,
    tag: 'Metas',
    audioUrl: '$_audioBase/meta_que_se_pueda_tocar.mp3',
    cuerpo: '''
«Quiero progresar» no es una meta. «Quiero un amoladora de 180 lucas en 12 semanas» sí lo es.

Para que una meta funcione en el oficio:

1. Nombre concreto (herramienta, repuesto, curso, arranque de stock).

2. Monto (lo que realmente cuesta hoy, no «más o menos»).

3. Ritmo (cuánto podés apartar por semana sin ahogar la casa).

Cada vez que cobrás y te queda un resto, en vez de dejarlo en el bolsillo, lo pasás a la meta. Así la plata tiene destino antes de que se evapore en gastos chicos.

Si la meta es una herramienta que te permite cobrar más o trabajar más rápido, conviene priorizarla: no es gusto, es inversión en el laburo.

Hacelo ahora
Creá una meta con nombre, monto y una fecha aproximada. La próxima vez que uses «Me saqué» o veas sobrante, pensá cuánto de eso puede ir a esa meta.
''',
  ),
  Leccion(
    id: 'vencimientos_que_no_se_ven',
    titulo: 'Los vencimientos que no se ven',
    resumen: 'Alquiler, monotributo, cuotas: que no te agarren desprevenido.',
    minutos: 3,
    tag: 'Vencimientos',
    audioUrl: '$_audioBase/vencimientos_que_no_se_ven.mp3',
    cuerpo: '''
Alquiler, expensas, monotributo, tarjeta, la cuota de la herramienta, el seguro del auto de trabajo. Si no están anotados, aparecen de golpe y se comen el mes bueno.

Vencimientos en la app sirve para una sola cosa: que no te agarren desprevenido.

Anotá:
• qué es,
• cuánto es,
• cuándo vence.

Cuando llega la fecha, ya sabés que esa plata no era «sobrante»: estaba comprometida. Así evitás gastar de más a principio de mes y después andar a las apuradas.

No hace falta cargar todo el universo el primer día. Empezá por los 3 o 4 que más te duelen cuando se te pasan.

Hacelo ahora
Entrá a Vencimientos y cargá al menos el próximo pago grande que tengas. El resto lo vas sumando de a uno.
''',
  ),
  Leccion(
    id: 'cuando_el_mes_aprieta',
    titulo: 'Cuando el mes aprieta',
    resumen: 'Qué tocar primero sin romper el negocio ni la casa.',
    minutos: 4,
    tag: 'Metas',
    audioUrl: '$_audioBase/cuando_el_mes_aprieta.mp3',
    cuerpo: '''
Hay meses flojos. La pregunta no es «¿por qué me va mal?», sino «¿qué toco primero sin romper el negocio ni la casa?».

Orden práctico:

1. No dejes de anotar Cobré / Gasté / Me saqué. Sin números, cualquier ajuste es a ciegas.

2. Revisá vencimientos de las próximas dos semanas: qué es ineludible y qué se puede negociar o postergar con tiempo.

3. El colchón es el freno de mano, no el combustible. Si lo usás, anotalo y después priorizá reponerlo.

4. Las metas aspiracionales se pausan, no se abandonan: bajás el aporte semanal a cero un tiempo, sin borrar la meta.

Pedir un préstamo en un mes flojo, sin mirar Semana/Mes y sin colchón, suele empeorar el problema. Primero orden; después, si hace falta, crédito con números claros (como vimos en el módulo de préstamos).

Hacelo ahora
Mirá Hoy / Semana / Mes y la lista de vencimientos de las próximas dos semanas. Con eso solo ya sabés si el mes está justo o si hay margen.
''',
  ),
];
