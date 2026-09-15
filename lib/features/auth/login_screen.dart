import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/biometric_service.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/network/api_exception.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/event_header_banner.dart';
import '../../core/widgets/ovum_logo.dart';
import '../../data/providers/biometric_provider.dart';
import '../../data/providers/user_provider.dart';
import 'biometric_enroll_sheet.dart';

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
  void initState() {
    super.initState();
    // Deja el correo puesto aunque no se use la huella: es el mismo usuario.
    final guardado = ref.read(biometricPrefsProvider).email;
    if (guardado.isNotEmpty) _emailCtrl.text = guardado;
  }

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

  /// Verifica la identidad y reusa las credenciales guardadas para volver a
  /// llamar a `POST /login`. El token anterior se revocó al cerrar sesión, así
  /// que hace falta una sesión nueva de verdad.
  Future<void> _loginConBiometria() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? correoGuardado;
    try {
      final r = await ref.read(biometricPrefsProvider.notifier).unlock();
      final creds = r.credentials;
      if (creds == null) {
        // Cancelar no es un error: no se pinta nada.
        if (!r.result.isSilent && mounted) {
          setState(() => _error = r.result.message);
        }
        return;
      }
      correoGuardado = creds.email;
      await ref
          .read(authControllerProvider.notifier)
          .login(creds.email, creds.password, rememberForBiometrics: false);
      if (mounted) context.go(R.home);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // La contraseña cambió o la revocaron: lo guardado ya no sirve.
        await ref.read(biometricPrefsProvider.notifier).disable();
        if (mounted) {
          setState(() {
            _emailCtrl.text = correoGuardado ?? _emailCtrl.text;
            _passwordCtrl.clear();
            _error = 'Tu contraseña cambió. Ingrésala de nuevo y vuelve a '
                'activar el acceso rápido.';
          });
        }
      } else if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo iniciar sesión. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            ..._accesoRapido(theme),
          ],
        ),
      ),
    );
  }

  /// Botón de acceso rápido. Solo aparece si el usuario lo activó antes y el
  /// dispositivo sigue siendo capaz de verificar la identidad (puede haber
  /// dejado de serlo: quitó el bloqueo, cambió de teléfono restaurando, etc.).
  List<Widget> _accesoRapido(ThemeData theme) {
    final bio = ref.watch(biometricPrefsProvider);
    final disponible = ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    if (!bio.isReady || !disponible) return const [];

    final kind =
        ref.watch(biometricKindProvider).valueOrNull ?? BiometricKind.fingerprint;
    return [
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _busy ? null : _loginConBiometria,
        icon: Icon(biometricIcon(kind), size: 20),
        label: Text('Entrar con ${biometricLabel(kind)}'),
      ),
      const SizedBox(height: 6),
      Text(
        bio.email,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    ];
  }
}
