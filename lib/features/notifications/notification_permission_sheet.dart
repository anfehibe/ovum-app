import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/app_icons.dart';
import '../../data/providers/notifications_provider.dart';

/// Hoja explicativa previa al diálogo del sistema.
///
/// En iOS el permiso de notificaciones **solo se puede pedir una vez**: si el
/// usuario lo rechaza, no hay segunda oportunidad salvo que entre a Ajustes.
/// Por eso primero se explica para qué sirve y solo "Activar" dispara el
/// diálogo real.
Future<void> showNotificationPermissionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final activar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _PermissionSheet(),
  );

  // Se marca como vista aunque diga "Ahora no": no se insiste en cada arranque.
  await ref.read(notificationPrefsProvider.notifier).markPromptSeen();

  if (activar != true) return;

  final concedido = await ref
      .read(notificationServiceProvider)
      .requestPermission();
  if (concedido) {
    await ref.read(pushRegistrationProvider.notifier).register();
  }
}

class _PermissionSheet extends StatelessWidget {
  const _PermissionSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsRegular.bellRinging,
                size: 28,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text('No te pierdas nada', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Activa las notificaciones para enterarte de los cambios de '
              'agenda y los anuncios del congreso, y para que te avisemos '
              'antes de que empiecen las sesiones que guardes.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Ahora no'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Activar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
