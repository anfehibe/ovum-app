import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/networking_provider.dart';

/// Error de una pestaña de networking.
///
/// Un **401 significa sesión vencida** (p. ej. si el usuario inició sesión en otro
/// dispositivo: el backend guarda un solo `api_token` por usuario). En ese caso
/// mostrar el `"Unauthenticated."` crudo del backend no ayuda a nadie, así que se
/// re-evalúa la compuerta para que toda la pantalla caiga al prompt de iniciar
/// sesión. No hay riesgo de bucle: la compuerta vuelve a dar `signInRequired` y
/// estas pestañas se desmontan.
class NetworkingTabError extends ConsumerWidget {
  const NetworkingTabError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error is ApiException ? error as ApiException : null;
    if (e != null && e.isUnauthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(networkingAccessProvider);
      });
      return const LoadingView();
    }
    return ErrorView(message: e?.message);
  }
}
