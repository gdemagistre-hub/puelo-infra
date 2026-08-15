part of puelo_homepage;

  Widget _buildBrandHeader({required String subtitle}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor, primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 40),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                tooltip: 'Menú',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hola, $_nombreMostrar', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.15)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.90), fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (_puedeSerAmbos) ...[
                GestureDetector(
                  onTap: () => setState(() => _modoPrestador = !_modoPrestador),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.35))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_modoPrestador ? Icons.handyman_rounded : Icons.search_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_modoPrestador ? 'Ofrezco' : 'Busco', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: _subiendoFoto ? null : _mostrarOpcionesSelfie,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildAvatarHeader(),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.photo_camera_rounded, size: 11, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClienteHome() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildBrandHeader(subtitle: '¿Qué servicio necesitás hoy?'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Material(
            color: Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _submitBusqueda,
              decoration: InputDecoration(
                hintText: '¿Qué servicio necesitás?',
                prefixIcon: Icon(Icons.search_rounded, color: _clientePrimary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        if (_sugerencias.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: _sugerencias
                    .map((e) => ListTile(
                          dense: true,
                          title: Text(e.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () => _elegirSugerencia(e),
                        ))
                    .toList(),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text('Oficios', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categorias.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final cat = _categorias[index];
              final Color accent = (cat['color'] as Color?) ?? _clientePrimary;
              return InkWell(
                onTap: () => _abrirBuscador(oficio: cat['id'] as String),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
                      ),
                      child: Icon(cat['icon'] as IconData, color: accent, size: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(cat['label'] as String, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Material(
            borderRadius: BorderRadius.circular(20),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _abrirBuscador(),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: [_clientePrimary, _clienteDark]),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prestadores con más confianza', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          SizedBox(height: 6),
                          Text('Ordenados por zona y calificación', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.verified_user_rounded, color: Colors.white, size: 34),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> get _dp => Map<String, dynamic>.from(UserSession().datosCompletos ?? {});

  bool _noVacio(dynamic v) {
    if (v == null) return false;
    return v.toString().trim().isNotEmpty;
  }

  void _abrirFlotante(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  List<_RecoItem> _recomendacionesPrestador(Map<String, dynamic> data) {
    final out = <_RecoItem>[];
    void add(_RecoItem r) {
      if (out.length < 5) out.add(r);
    }

    final geo = data['direccion_geo'] is Map
        ? Map<String, dynamic>.from(data['direccion_geo'] as Map)
        : <String, dynamic>{};
    final profesiones = data['profesiones'] as List? ?? [];
    final zonas = data['zonas_cobertura'] is Map
        ? Map<String, dynamic>.from(data['zonas_cobertura'] as Map)
        : <String, dynamic>{};
    final locs = zonas['localidades'] as List? ?? [];
    final vals = data['validaciones_recibidas'] as List? ?? [];
    final fotoPerfil = _noVacio(data['url_foto_perfil'] ?? data['foto_perfil']);
    final docValidado = data['doc_validado'] == true;
    final tieneTel = _noVacio(data['telefono']);
    final tieneEmail = _noVacio(data['email']);
    final tieneLocalidad = _noVacio(geo['localidad_id'] ?? geo['localidad_nombre']);
    final tieneCalle = _noVacio(data['calle']);
    final tieneDoc = _noVacio(data['doc_numero'] ?? data['numero_documento'] ?? data['documento']);

    if (!fotoPerfil) {
      add(_RecoItem(
        id: 'foto_perfil',
        title: 'Sumá una foto de perfil',
        subtitle: 'Selfie clara · suma fuerte a tu Confianza',
        icon: Icons.photo_camera_rounded,
        onTap: _mostrarOpcionesSelfie,
      ));
    }
    if (!docValidado) {
      add(_RecoItem(
        id: 'ocr',
        title: 'Validá tu documento con la cámara',
        subtitle: 'El mayor salto de Confianza · DNI escaneado',
        icon: Icons.badge_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    } else if (!_noVacio(data['url_foto_documento'])) {
      add(_RecoItem(
        id: 'foto_doc',
        title: 'Adjuntá la foto de tu documento',
        subtitle: 'Refuerza que el documento es real',
        icon: Icons.image_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (!tieneTel) {
      add(_RecoItem(
        id: 'tel',
        title: 'Cargá tu celular',
        subtitle: 'Para que te contacten por WhatsApp o llamada',
        icon: Icons.phone_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (!tieneLocalidad || !tieneCalle) {
      add(_RecoItem(
        id: 'domicilio',
        title: 'Completá tu domicilio',
        subtitle: 'Provincia, partido y localidad · suma Confianza',
        icon: Icons.home_outlined,
        onTap: () => _abrirFlotante(DomicilioFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (vals.isEmpty) {
      add(_RecoItem(
        id: 'validacion',
        title: 'Pedí que validen quién sos',
        subtitle: 'Un conocido confirma tu perfil · reputación real',
        icon: Icons.how_to_reg_outlined,
        onTap: () => _abrirFlotante(const SolicitarValidacionWidget()),
      ));
    }
    if (!tieneEmail) {
      add(_RecoItem(
        id: 'email',
        title: 'Cargá tu email en el perfil',
        subtitle: 'Suma a tu Confianza y facilita el contacto',
        icon: Icons.email_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (!tieneDoc) {
      add(_RecoItem(
        id: 'doc_numero',
        title: 'Cargá tipo y número de documento',
        subtitle: 'No se muestra al cliente · valida tu identidad',
        icon: Icons.credit_card_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (profesiones.isEmpty) {
      add(_RecoItem(
        id: 'oficios',
        title: 'Indicá los servicios que ofrecés',
        subtitle: 'Así aparecés cuando buscan tu rubro',
        icon: Icons.handyman_outlined,
        onTap: () => _abrirFlotante(const EspecialidadesLaboralesFlotanteWidget()),
      ));
    }
    if (locs.isEmpty) {
      add(_RecoItem(
        id: 'zona',
        title: 'Definí tu zona de trabajo',
        subtitle: 'Para que te encuentren en tu área',
        icon: Icons.map_outlined,
        onTap: () => _abrirFlotante(const ZonaDeTrabajoFlotanteWidget()),
      ));
    }
    if (out.length < 5) {
      add(_RecoItem(
        id: 'fotos_trabajo',
        title: 'Subí fotos de trabajos hechos',
        subtitle: 'Hasta 5 cuentan en tu Confianza',
        icon: Icons.photo_library_outlined,
        onTap: () => _abrirFlotante(const CargaTrabajoTrabajadorWidget()),
      ));
    }

    return out;
  }

  Widget _buildPrestadorHome() {
    final badge = (_dp['list_badge'] ?? _dp['badge_prestador'] ?? '').toString().trim();
    final label = ScoringService.labelBadge(badge.isEmpty ? null : badge);
    final colors = ScoringService.coloresBadge(badge.isEmpty ? null : badge);
    final starsRaw = _dp['list_promedio'] ?? _dp['promedioEstrellas'] ?? 0;
    final stars = starsRaw is num ? starsRaw.toDouble() : (double.tryParse('$starsRaw') ?? 0);
    final nRaw = _dp['list_n_evaluaciones'] ?? _dp['nEvaluaciones'] ?? _dp['cantidad_evaluaciones'] ?? 0;
    final nEval = nRaw is num ? nRaw.toInt() : (int.tryParse('$nRaw') ?? 0);
    final scoreRaw = _dp['list_score_identidad'];
    int score = 0;
    if (scoreRaw is num) {
      score = scoreRaw.toInt();
    } else {
      final sc = _dp['scoring'];
      if (sc is Map && sc['score_identidad'] is num) score = (sc['score_identidad'] as num).toInt();
    }
    final scoreClamped = score.clamp(0, 100);
    final scoreProgress = scoreClamped / 100.0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildBrandHeader(subtitle: 'Tu perfil profesional en Puelo'),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              borderRadius: BorderRadius.circular(22),
              elevation: 8,
              shadowColor: _prestadorPrimary.withOpacity(0.35),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [Colors.white, _prestadorPrimary.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: _prestadorPrimary.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Así te ven los clientes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label.isNotEmpty ? label : 'Sin nivel aún',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: label.isNotEmpty ? Color(colors.foreground) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nEval > 0 ? '${stars.toStringAsFixed(1)} ($nEval)' : '—',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                      Text(
                                        nEval > 0 ? 'Calificación' : 'Sin evaluaciones',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: CircularProgressIndicator(
                                          value: score > 0 ? scoreProgress : 0,
                                          strokeWidth: 5,
                                          backgroundColor: const Color(0xFFE2E8F0),
                                          color: const Color(0xFF16A34A),
                                          strokeCap: StrokeCap.round,
                                        ),
                                      ),
                                      Text(
                                        score > 0 ? '$scoreClamped' : '—',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        score > 0 ? '$scoreClamped / 100' : '—',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'Confianza',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Material(
            borderRadius: BorderRadius.circular(18),
            elevation: 3,
            child: InkWell(
              onTap: _compartirTarjeta,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [_prestadorPrimary, _prestadorDark]),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu tarjeta digital',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Compartila y que te contacten',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
        Builder(
          builder: (context) {
            final recos = _recomendacionesPrestador(_dp);
            if (recos.isEmpty) {
              return const SizedBox(height: 32);
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para subir tu Confianza',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atajos que suman puntos ya',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  ...recos.map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 1,
                        child: InkWell(
                          onTap: r.onTap,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _prestadorPrimary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(r.icon, color: _prestadorPrimary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        r.subtitle,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RecoItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _RecoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}
