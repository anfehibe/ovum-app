import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/network/api_exception.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/event_header_banner.dart';
import '../../core/widgets/ovum_logo.dart';
import '../../data/providers/user_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) context.go(R.home);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error =
            e.isUnauthorized ? 'Correo o contraseña incorrectos.' : e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo iniciar sesión. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginAsGuest() async {
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).loginAsGuest();
    if (mounted) context.go(R.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6C453), BrandColors.yolk, BrandColors.sunrise],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              // Fuerza el contenido a ocupar al menos toda la pantalla para que el
              // gradiente llene el fondo (evita la franja blanca inferior).
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  // Banner del congreso: ancho completo, en el tope, fuera del safe
                  // area (solo el espacio de la status bar; el gradiente va detrás).
                  Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: EventHeaderBanner(fallback: _brandingFallback(theme)),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
                    child: Column(
                      children: [
                        _loginCard(theme),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _busy ? null : _loginAsGuest,
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          child: const Text(AppStrings.enterAsGuest),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Header de marca (fallback cuando aún no hay banner del API).
  Widget _brandingFallback(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OvumEggMark(size: 84, onDark: true),
        const SizedBox(height: 20),
        Text(
          'OVUM 2026',
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          OvumEvent.edition,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
        ),
        ],
      ),
    );
  }

  Widget _loginCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bienvenido', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Ingresa para vivir el congreso',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'tu@correo.com',
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Ingresa tu correo';
                if (!value.contains('@')) return 'Correo no válido';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
              onFieldSubmitted: (_) {
                if (!_busy) _login();
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _login,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AppStrings.login),
            ),
          ],
        ),
      ),
    );
  }
}
