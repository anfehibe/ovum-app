import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../data/providers/user_provider.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';

/// Invitación a iniciar sesión, para las secciones que exigen Bearer (asistentes,
/// networking). El botón llama a `logout()` a propósito: cierra la sesión de
/// invitado y el router redirige al login.
class SignInPrompt extends ConsumerWidget {
  const SignInPrompt({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? PhosphorIconsRegular.usersThree,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              child: const Text(AppStrings.login),
            ),
          ],
        ),
      ),
    );
  }
}
