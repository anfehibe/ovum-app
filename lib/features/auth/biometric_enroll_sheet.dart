import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/biometric_service.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/app_icons.dart';
import '../../data/providers/biometric_provider.dart';
import '../../data/providers/user_provider.dart';

/// Cómo nombrar la biometría del dispositivo en los textos de la UI.
///
/// En Android nunca sabemos si es huella o rostro (el plugin solo reporta
/// `strong`/`weak`), así que el texto genérico "tu huella" cubre ese caso.
String biometricLabel(BiometricKind kind) => switch (kind) {
  BiometricKind.faceId => 'Face ID',
  BiometricKind.touchId => 'Touch ID',
  BiometricKind.fingerprint => 'tu huella',
  BiometricKind.none => 'el bloqueo del dispositivo',
};

IconData biometricIcon(BiometricKind kind) => kind == BiometricKind.faceId
    ? PhosphorIconsRegular.scanSmiley
    : PhosphorIconsRegular.fingerprint;

/// Hoja explicativa previa a activar el acceso rápido, justo después del login.
///
/// En iOS el diálogo de permiso de Face ID aparece en la **primera** llamada a
/// `authenticate()`, así que primero se explica para qué sirve y solo "Activar"
/// lo dispara — mismo criterio que la hoja de notificaciones.
Future<void> showBiometricEnrollSheet(
  BuildContext context,
  WidgetRef ref, {
  required String email,
  required String password,
  required BiometricKind kind,
}) async {
  final activar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _EnrollSheet(kind: kind),
  );

  // Se marca como vista aunque diga "Ahora no": no se insiste en cada login.
  await ref.read(biometricPrefsProvider.notifier).markPromptSeen();
  if (activar != true) return;

  final result = await ref
      .read(biometricPrefsProvider.notifier)
      .enable(email: email, password: password);

  if (!context.mounted) return;
  if (result.isOk) {
    _aviso(context, 'Listo: la próxima vez entra con ${biometricLabel(kind)}.');
  } else if (!result.isSilent && result.message != null) {
    _aviso(context, result.message!);
  }
}

/// Activación desde Perfil. A diferencia del post-login, aquí no tenemos la
/// contraseña en ninguna parte, así que hay que pedirla y validarla contra el
/// backend antes de guardarla.
Future<void> showBiometricEnableSheet(
  BuildContext context,
  WidgetRef ref, {
  required String email,
  required BiometricKind kind,
}) async {
  final password = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      // Deja sitio al teclado: la hoja lleva un campo de texto.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _PasswordSheet(email: email, kind: kind),
    ),
  );
  if (password == null || password.isEmpty || !context.mounted) return;

  try {
    // Reutiliza el flujo real de login: valida la contraseña, refresca el
    // Bearer y re-registra el push. `rememberForBiometrics: false` porque la
    // oferta la estamos atendiendo aquí mismo.
    await ref
        .read(authControllerProvider.notifier)
        .login(email, password, rememberForBiometrics: false);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    _aviso(
      context,
      e.isUnauthorized ? 'Contraseña incorrecta.' : e.message,
    );
    return;
  } catch (_) {
    if (!context.mounted) return;
    _aviso(context, 'No se pudo verificar tu contraseña. Intenta de nuevo.');
    return;
  }

  final result = await ref
      .read(biometricPrefsProvider.notifier)
      .enable(email: email, password: password);

  if (!context.mounted) return;
  if (result.isOk) {
    _aviso(context, 'Acceso rápido activado con ${biometricLabel(kind)}.');
  } else if (!result.isSilent && result.message != null) {
    _aviso(context, result.message!);
  }
}

void _aviso(BuildContext context, String texto) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

class _EnrollSheet extends StatelessWidget {
  const _EnrollSheet({required this.kind});

  final BiometricKind kind;

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
                biometricIcon(kind),
                size: 28,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text('Entra más rápido', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Usa ${biometricLabel(kind)} en lugar de escribir tu correo y tu '
              'contraseña cada vez. Se guardan cifrados en este dispositivo y '
              'nunca salen de él.',
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

/// Pide la contraseña para poder guardarla. Devuelve `null` si se cancela.
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.email, required this.kind});

  final String email;
  final BiometricKind kind;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    final value = _ctrl.text;
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

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
                biometricIcon(widget.kind),
                size: 28,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text('Activar acceso rápido', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Confirma la contraseña de ${widget.email} para guardarla '
              'cifrada en este dispositivo.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _confirmar(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirmar,
                    child: const Text('Continuar'),
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
