import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/user_provider.dart';

/// Eliminar la cuenta (`DELETE /me`). Lo exige App Store en toda app con cuentas.
///
/// Pide la contraseña (el backend la verifica) y un diálogo de confirmación. Si
/// el borrado falla no se toca nada local; si sale bien, `deleteAccount` deja
/// la sesión en `null` y el router vuelve solo al login.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const _generico = 'No se pudo eliminar la cuenta. Intenta de nuevo.';

  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _eliminar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!await _confirmar()) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(_passwordCtrl.text);
      messenger.showSnackBar(
        const SnackBar(content: Text('Tu cuenta fue eliminada.')),
      );
      // El router ya redirige al quedar la sesión en null; esto cubre el caso
      // en que la pantalla siga montada.
      if (mounted) context.go(R.login);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _mensajeDe(e));
    } catch (_) {
      if (mounted) setState(() => _error = _generico);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mensajeDe(ApiException e) {
    if (e.isRateLimited) {
      return 'Demasiados intentos. Espera un minuto y vuelve a intentarlo.';
    }
    if (e.isUnauthorized) {
      return 'Tu sesión venció. Cierra sesión, vuelve a entrar e inténtalo de nuevo.';
    }
    // 404/405: un backend sin `DELETE /me` (producción lo tiene desde `6efc10d`).
    if (e.statusCode == 404 || e.statusCode == 405) {
      return 'Esta opción todavía no está disponible. Intenta de nuevo más tarde.';
    }
    // El 422 ya llega en español ("La contraseña no es correcta.").
    final msg = e.message.trim();
    return msg.isEmpty ? _generico : msg;
  }

  Future<bool> _confirmar() async {
    final scheme = context.scheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Se borrarán tus datos y ya no podrás entrar con esta cuenta. '
          'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final email = ref.watch(currentUserProvider)?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar mi cuenta')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(PhosphorIconsRegular.warning, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Esta acción no se puede deshacer',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: scheme.onErrorContainer),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Vas a eliminar la cuenta $email.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.onErrorContainer),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Qué se borra', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _punto(context, 'Tus datos personales y de contacto.'),
            _punto(context, 'Tu perfil de networking, tus favoritos y tus reuniones.'),
            _punto(context, 'El acceso rápido con Face ID o huella en este teléfono.'),
            const SizedBox(height: 4),
            Text(
              'Después ya no podrás entrar con esta cuenta.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text('Qué se conserva', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _punto(
              context,
              'Tus inscripciones y pagos, por obligaciones contables y fiscales. '
              'Quedan sin tus datos de contacto.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                helperText: 'Escríbela para confirmar que eres tú.',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
              onFieldSubmitted: (_) {
                if (!_busy) _eliminar();
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _eliminar,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                minimumSize: const Size(0, 48),
              ),
              icon: _busy
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onError,
                      ),
                    )
                  : const Icon(PhosphorIconsRegular.trash, size: 18),
              label: const Text('Eliminar mi cuenta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _punto(BuildContext context, String texto) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: context.scheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(texto, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
