import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/sign_in_prompt.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/networking_provider.dart';

/// Envuelve una pantalla que depende del networking y resuelve los cuatro
/// estados de la compuerta.
///
/// Existe para no repetir el mismo `switch` en cada pantalla del módulo: lo usan
/// las dos de mensajería. `networking_screen.dart` mantiene el suyo porque su
/// caso "cerrado" muestra además el roster de asistentes de solo lectura.
class NetworkingGate extends ConsumerWidget {
  const NetworkingGate({
    super.key,
    required this.signInMessage,
    required this.builder,
  });

  final String signInMessage;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(networkingAccessProvider);
    return access.when(
      loading: () => const LoadingView(),
      error: (_, _) => _retry(ref, null),
      data: (a) {
        if (a.isOpen) return builder(context);
        return switch (a.block!) {
          NetworkingBlock.signInRequired => SignInPrompt(message: signInMessage),
          NetworkingBlock.failed => _retry(ref, a.message),
          NetworkingBlock.closed || NetworkingBlock.disabled => _closed(context, a.message),
        };
      },
    );
  }

  Widget _retry(WidgetRef ref, String? message) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ErrorView(message: message),
      const SizedBox(height: 12),
      FilledButton.tonal(
        onPressed: () => ref.invalidate(networkingAccessProvider),
        child: const Text('Reintentar'),
      ),
    ],
  );

  /// Networking cerrado. Aquí no se ofrece el roster de asistentes como
  /// alternativa: tiene sentido para un directorio, no para "mis conversaciones".
  Widget _closed(BuildContext context, String message) {
    final scheme = context.scheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.chatsCircle,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message.isEmpty
                  ? 'La mensajería no está disponible para este evento.'
                  : message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
