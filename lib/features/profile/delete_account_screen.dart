import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/l10n/l10n.dart';
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
    final deletedMsg = context.l10n.profileAccountDeleted;
    final genericError = context.l10n.profileDeleteGenericError;
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(_passwordCtrl.text);
      messenger.showSnackBar(
        SnackBar(content: Text(deletedMsg)),
      );
      // El router ya redirige al quedar la sesión en null; esto cubre el caso
      // en que la pantalla siga montada.
      if (mounted) context.go(R.login);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _mensajeDe(e));
    } catch (_) {
      if (mounted) setState(() => _error = genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mensajeDe(ApiException e) {
    if (e.isRateLimited) {
      return context.l10n.profileTooManyAttempts;
    }
    if (e.isUnauthorized) {
      return context.l10n.profileSessionExpired;
    }
    // 404/405: un backend sin `DELETE /me` (producción lo tiene desde `6efc10d`).
    if (e.statusCode == 404 || e.statusCode == 405) {
      return context.l10n.profileOptionUnavailable;
    }
    // El 422 ya llega en español ("La contraseña no es correcta.").
    final msg = e.message.trim();
    return msg.isEmpty ? context.l10n.profileDeleteGenericError : msg;
  }

  Future<bool> _confirmar() async {
    final scheme = context.scheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.profileDeleteAccountConfirmTitle),
        content: Text(context.l10n.profileDeleteAccountConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: Text(context.l10n.profileDelete),
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
      appBar: AppBar(title: Text(context.l10n.profileDeleteMyAccount)),
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
                          context.l10n.profileActionCannotBeUndone,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: scheme.onErrorContainer),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.profileYouWillDeleteAccount(email),
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
            Text(context.l10n.profileWhatIsDeleted, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _punto(context, context.l10n.profileDeletedPersonalData),
            _punto(context, context.l10n.profileDeletedNetworkingProfile),
            _punto(context, context.l10n.profileDeletedQuickAccess),
            const SizedBox(height: 4),
            Text(
              context.l10n.profileNoLongerLogin,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(context.l10n.profileWhatIsKept, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _punto(context, context.l10n.profileKeptRegistrations),
            const SizedBox(height: 24),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: context.l10n.profilePassword,
                helperText: context.l10n.profilePasswordHelper,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? context.l10n.profileEnterPassword : null,
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
              label: Text(context.l10n.profileDeleteMyAccount),
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
