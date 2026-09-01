import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Homepage.dart';
import 'elige_camino.dart';
import 'geo/country_profile.dart';
import 'user_session.dart';

/// Primera vez: país de operación. Trio AR/CL/UY habilitado. Default visual AR.
/// [modoCambio] = ya tiene país y lo cambia desde perfil/domicilio.
class EligePaisWidget extends StatefulWidget {
  static const String routeName = 'EligePais';
  static const String routePath = '/elige-pais';

  final bool modoCambio;

  const EligePaisWidget({super.key, this.modoCambio = false});

  static bool necesitaElegir() {
    final data = UserSession().datosCompletos;
    if (data == null) return false;
    final raw = (data['country_code'] ?? '').toString().trim();
    if (raw.isNotEmpty) return false;
    if (data['pais_confirmado'] == true) return false;
    return true;
  }

  @override
  State<EligePaisWidget> createState() => _EligePaisWidgetState();
}

class _EligePaisWidgetState extends State<EligePaisWidget> {
  static const Color _accent = Color(0xFF734BE4);

  late String _iso;
  bool _saving = false;

  List<CountryProfile> get _paises => CountryProfile.listedForSelector;

  @override
  void initState() {
    super.initState();
    final actual = (UserSession().datosCompletos?['country_code'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    _iso = CountryProfile.isLaunch(actual)
        ? actual
        : CountryProfile.defaultIso;
  }

  Future<void> _confirmar() async {
    if (_saving) return;
    if (!CountryProfile.isLaunch(_iso)) return;
    setState(() => _saving = true);

    final pais = CountryProfile.of(_iso);
    final uid = UserSession().uid;
    final anterior = (UserSession().datosCompletos?['country_code'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final cambioPais = widget.modoCambio && anterior != pais.iso;

    final patch = <String, dynamic>{
      'country_code': pais.iso,
      'currency': pais.currency,
      'pais_confirmado': true,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (cambioPais) {
      patch['direccion_geo'] = FieldValue.delete();
      patch['zonas_cobertura'] = FieldValue.delete();
    }

    try {
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .set(patch, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('EligePais save error: $e');
    }

    final data = Map<String, dynamic>.from(UserSession().datosCompletos ?? {});
    data['country_code'] = pais.iso;
    data['currency'] = pais.currency;
    data['pais_confirmado'] = true;
    if (cambioPais) {
      data.remove('direccion_geo');
      data.remove('zonas_cobertura');
    }
    UserSession().datosCompletos = data;
    UserSession().invalidateHomeCache();
    UserSession().notifyProfileChanged();

    if (!mounted) return;

    if (widget.modoCambio) {
      Navigator.pop(context, pais.iso);
      return;
    }

    if (EligeCaminoWidget.necesitaElegir()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EligeCaminoWidget()),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePageWidget(
          initialModoPrestador: UserSession().preferredHomeModoPrestador,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: widget.modoCambio
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: const Color(0xFF0F172A),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'País',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              centerTitle: false,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.modoCambio) const SizedBox(height: 24),
              Text(
                widget.modoCambio
                    ? '¿En qué país operás ahora?'
                    : '¿En qué país trabajás?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.modoCambio
                    ? 'Si cambiás de país se borra la ubicación anterior '
                        'para elegir las zonas de ese catálogo.'
                    : 'Empezamos por Argentina, Chile y Uruguay. '
                        'El resto de la región se va a ir habilitando.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _paises.length,
                  separatorBuilder: (context, i) {
                    if (i == CountryProfile.launchIsos.length - 1) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                        child: Text(
                          'Próximamente',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.4,
                          ),
                        ),
                      );
                    }
                    return const SizedBox(height: 8);
                  },
                  itemBuilder: (context, i) {
                    final p = _paises[i];
                    final enabled = p.launchReady;
                    final selected = enabled && p.iso == _iso;
                    return Opacity(
                      opacity: enabled ? 1 : 0.45,
                      child: Material(
                        color: enabled ? Colors.white : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: (!enabled || _saving)
                              ? null
                              : () => setState(() => _iso = p.iso),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? _accent
                                    : const Color(0xFFE2E8F0),
                                width: selected ? 1.6 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: enabled
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(Icons.check_circle, color: _accent),
                                if (!enabled)
                                  const Text(
                                    'Próximamente',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _saving
                        ? 'Guardando…'
                        : (widget.modoCambio ? 'Guardar país' : 'Continuar'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
