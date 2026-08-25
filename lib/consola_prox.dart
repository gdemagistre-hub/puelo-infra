import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'scoring_service.dart';
import 'user_session.dart';

/// Consola de monitoreo Prox.
class ConsolaProxWidget extends StatefulWidget {
  const ConsolaProxWidget({super.key});

  static const String routeName = 'ConsolaProx';
  static const String routePath = '/consolaProx';

  static bool get puedeAcceder => UserSession().isAdmin;

  @override
  State<ConsolaProxWidget> createState() => _ConsolaProxWidgetState();
}
