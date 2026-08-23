        Builder(
          builder: (context) {
            final recos = _recomendacionesPrestador(_dp);
            if (recos.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Material(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _compartirTarjeta,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Perfil listo para que te encuentren',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF14532D),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Compartí tu tarjeta por WhatsApp',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.ios_share_rounded, color: Color(0xFF16A34A)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            final pendientes = recos
                .where((r) => !_tipsVisitadosSesion.contains(r.id))
                .toList();
            final primero = pendientes.isNotEmpty ? pendientes.first : recos.first;
            final resto = recos.where((r) => r.id != primero.id).toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para subir tu Confianza',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pendientes.length <= 1
                        ? 'Este es el paso que más te conviene ahora'
                        : 'Empezá por el primero · te faltan ${pendientes.length} pasos',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  _tipTile(primero, destacado: true),
                  if (resto.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < resto.length; i++)
                            _tipTile(
                              resto[i],
                              destacado: false,
                              numero: i + 2,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
  Widget _tipTile(_RecoItem r, {required bool destacado, int? numero}) {
    final visitado = _tipsVisitadosSesion.contains(r.id);
    final border = destacado && !visitado
        ? Border.all(color: _prestadorPrimary, width: 1.6)
        : null;
    return Padding(
      padding: EdgeInsets.only(bottom: destacado ? 0 : 6),
      child: Opacity(
        opacity: visitado ? 0.55 : 1,
        child: Material(
          color: visitado
              ? const Color(0xFFF1F5F9)
              : (destacado ? Colors.white : Colors.transparent),
          elevation: destacado && !visitado ? 2 : 0,
          shadowColor: _prestadorPrimary.withOpacity(0.25),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _ejecutarTip(r),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: destacado
                          ? _prestadorPrimary.withOpacity(0.16)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: visitado
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF16A34A), size: 22)
                        : (numero != null
                            ? Text(
                                '$numero',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            : Icon(r.icon, color: _prestadorPrimary, size: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (destacado && !visitado)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              'SIGUIENTE PASO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: Color(0xFF1A8FA3),
                              ),
                            ),
                          ),
                        Text(
                          r.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: destacado ? 15 : 14,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    visitado
                        ? Icons.check_circle_outline_rounded
                        : Icons.chevron_right_rounded,
                    color: visitado
                        ? const Color(0xFF94A3B8)
                        : (destacado
                            ? _prestadorPrimary
                            : Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
