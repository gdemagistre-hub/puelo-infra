class _HintContacto {
  final String uid;
  final String nombre;
  final bool entrante;
  final String tipo;
  _HintContacto({
    required this.uid,
    required this.nombre,
    required this.entrante,
    required this.tipo,
  });
}

class _EmptyState extends StatefulWidget {
  final VoidCallback onEmitir;
  final void Function(String uid, String nombre) onEmitirA;
  const _EmptyState({required this.onEmitir, required this.onEmitirA});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  List<_HintContacto> _hints = const [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final me = UserSession().uid;
    if (me == null || me.isEmpty) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    try {
      final db = FirebaseFirestore.instance.collection('contactos');
      final yoCliente = await db.where('cliente_uid', isEqualTo: me).limit(30).get();
      final yoPrestador = await db.where('prestador_uid', isEqualTo: me).limit(30).get();

      DateTime when(Map<String, dynamic> d) {
        final t = d['created_at'];
        return t is Timestamp ? t.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      }

      final scored = <_HintContacto, DateTime>{};
      final seen = <String>{};

      void add(QueryDocumentSnapshot<Map<String, dynamic>> doc, {required bool entrante}) {
        final d = doc.data();
        final other = (entrante ? d['cliente_uid'] : d['prestador_uid'])
            .toString()
            .trim();
        if (other.isEmpty || other == me || !seen.add(other)) return;
        final hint = (entrante
                ? (d['cliente_nombre'] ?? '')
                : (d['prestador_nombre'] ?? ''))
            .toString()
            .trim();
        scored[_HintContacto(
          uid: other,
          nombre: hint,
          entrante: entrante,
          tipo: (d['tipo'] ?? 'whatsapp').toString(),
        )] = when(d);
      }

      for (final d in yoPrestador.docs) {
        add(d, entrante: true);
      }
      for (final d in yoCliente.docs) {
        add(d, entrante: false);
      }

      final list = scored.keys.toList()
        ..sort((a, b) => scored[b]!.compareTo(scored[a]!));

      final missing = list.where((h) => h.nombre.isEmpty).take(5);
      await Future.wait(missing.map((h) async {
        try {
          final u = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(h.uid)
              .get();
          final data = u.data() ?? {};
          final comercial = (data['nombre_comercial'] ?? '').toString().trim();
          final n = (data['nombre'] ?? '').toString().trim();
          final a = (data['apellido'] ?? '').toString().trim();
          final label = comercial.isNotEmpty ? comercial : '$n $a'.trim();
          if (label.isEmpty) return;
          final i = list.indexWhere((x) => x.uid == h.uid);
          if (i >= 0) {
            list[i] = _HintContacto(
              uid: h.uid,
              nombre: label,
              entrante: h.entrante,
              tipo: h.tipo,
            );
          }
        } catch (_) {}
      }));

      if (!mounted) return;
      setState(() {
        _hints = list.take(5).toList();
        _ready = true;
      });
    } catch (e) {
      debugPrint('Mensajes empty contactos: $e');
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hints.isNotEmpty) {
      return _ContactosPendientes(
        hints: _hints,
        onEmitir: widget.onEmitir,
        onEmitirA: widget.onEmitirA,
      );
    }
    return _EmptyPasos(onEmitir: widget.onEmitir);
  }
}

class _ContactosPendientes extends StatelessWidget {
  final List<_HintContacto> hints;
  final VoidCallback onEmitir;
  final void Function(String uid, String nombre) onEmitirA;
  const _ContactosPendientes({
    required this.hints,
    required this.onEmitir,
    required this.onEmitirA,
  });

  @override
  Widget build(BuildContext context) {
    final hayEntrante = hints.any((h) => h.entrante);
    final haySaliente = hints.any((h) => !h.entrante);

    String blurb;
    if (haySaliente && !hayEntrante) {
      blurb =
          'Ya escribiste por WhatsApp. Cuando cierren el trabajo, registrá el comprobante.';
    } else if (hayEntrante && !haySaliente) {
      blurb =
          'Te contactaron. Cuando el cliente registre el pago, el comprobante aparece acá para confirmar.';
    } else {
      blurb =
          'Hay contactos en PROX. El comprobante se registra con Doy un pago; quien recibe lo confirma.';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      children: [
        const Text(
          'Todavía no hay comprobantes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MensajesListScreen._text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          blurb,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: MensajesListScreen._muted,
          ),
        ),
        const SizedBox(height: 18),
        ...hints.map((h) {
          final label = h.nombre.isEmpty ? 'Contacto' : h.nombre;
          final tag = h.entrante ? 'Te contactó' : 'Lo contactaste';
          final tipo = h.tipo == 'llamada' ? 'Llamada' : 'WhatsApp';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 1,
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
                leading: CircleAvatar(
                  backgroundColor: MensajesListScreen._primary.withOpacity(0.15),
                  child: Text(
                    label[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MensajesListScreen._primary,
                    ),
                  ),
                ),
                title: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                subtitle: Text(
                  '$tag · $tipo',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                trailing: h.entrante
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: () => onEmitirA(h.uid, label),
                        child: const Text(
                          'Doy un pago',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
              ),
            ),
          );
        }),
        if (haySaliente) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onEmitir,
            style: FilledButton.styleFrom(
              backgroundColor: MensajesListScreen._primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text(
              'Doy un pago',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyPasos extends StatelessWidget {
  final VoidCallback onEmitir;
  const _EmptyPasos({required this.onEmitir});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: MensajesListScreen._primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 44,
              color: MensajesListScreen._primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Todavía no hay actividad',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MensajesListScreen._text,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Acá aparecen los comprobantes de pago y las evaluaciones. '
          'Para el primer pago, seguí estos pasos:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: MensajesListScreen._muted,
          ),
        ),
        const SizedBox(height: 20),
        _StepRow(n: '1', text: 'Buscá un prestador en Inicio y abrí su tarjeta'),
        const SizedBox(height: 10),
        _StepRow(n: '2', text: 'Tocá WhatsApp o Llamar (queda el contacto)'),
        const SizedBox(height: 10),
        _StepRow(n: '3', text: 'Registrá el pago con “Doy un pago”'),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: onEmitir,
          style: FilledButton.styleFrom(
            backgroundColor: MensajesListScreen._primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.add),
          label: const Text(
            'Doy un pago',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String n;
  final String text;
  const _StepRow({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MensajesListScreen._primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            n,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: MensajesListScreen._primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: MensajesListScreen._text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
