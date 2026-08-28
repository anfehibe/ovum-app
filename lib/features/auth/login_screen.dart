import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authControllerProvider.notifier).loginWithEmail(_emailCtrl.text.trim());
      context.go(R.home);
    }
  }

  void _loginAsGuest() {
    ref.read(authControllerProvider.notifier).loginAsGuest();
    context.go(R.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6C453), BrandColors.yolk, BrandColors.sunrise],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 36),
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
                      const SizedBox(height: 32),
                      _loginCard(theme),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: _loginAsGuest,
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text(AppStrings.enterAsGuest),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
              onFieldSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _login,
              child: const Text(AppStrings.login),
            ),
          ],
        ),
      ),
    );
  }
}
