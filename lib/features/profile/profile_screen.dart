import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/auth/biometric_service.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../data/providers/biometric_provider.dart';
import '../../data/providers/favorites_provider.dart';
import '../../data/providers/notifications_provider.dart';
import '../../data/providers/user_provider.dart';
import '../auth/biometric_enroll_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final favCount = ref.watch(favoritesProvider).length;
    final notif = ref.watch(notificationPrefsProvider);
    final bio = ref.watch(biometricPrefsProvider);
    final bioDisponible =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final bioKind =
        ref.watch(biometricKindProvider).valueOrNull ?? BiometricKind.fingerprint;
    final scheme = context.scheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navProfile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _userCard(context, user?.name ?? 'Invitado', user?.position ?? '', user?.company ?? '',
              user?.email ?? '', user?.photoUrl),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push(R.profileEdit),
            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
            label: const Text('Editar perfil'),
          ),
          const SizedBox(height: 24),
          _tile(
            context,
            icon: PhosphorIconsRegular.heart,
            title: AppStrings.favorites,
            subtitle: favCount == 0 ? 'Sin favoritos aún' : '$favCount guardados',
            onTap: () => context.push(R.favorites),
          ),
          if (!(user?.isGuest ?? true)) ...[
            const SizedBox(height: 10),
            _tile(
              context,
              icon: PhosphorIconsRegular.identificationCard,
              title: 'Mi perfil de networking',
              subtitle: 'Sectores e intereses para que te encuentren',
              onTap: () => context.push(R.networkingProfile),
            ),
          ],
          const SizedBox(height: 24),
          Text('Notificaciones', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: notif.pushEnabled,
            onChanged: (v) =>
                ref.read(notificationPrefsProvider.notifier).setPush(v),
            secondary: const Icon(PhosphorIconsRegular.bellRinging),
            title: const Text('Avisos del congreso'),
            subtitle: const Text('Cambios de agenda y anuncios del organizador'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: notif.remindersEnabled,
            onChanged: (v) =>
                ref.read(notificationPrefsProvider.notifier).setReminders(v),
            secondary: const Icon(PhosphorIconsRegular.clockCountdown),
            title: const Text('Recordar mis sesiones'),
            subtitle: const Text('Aviso antes de las sesiones que guardaste'),
          ),
          if (notif.remindersEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'Avisarme con antelación de',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 5, label: Text('5 min')),
                ButtonSegment(value: 15, label: Text('15 min')),
                ButtonSegment(value: 30, label: Text('30 min')),
              ],
              selected: {notif.leadMinutes},
              onSelectionChanged: (s) => ref
                  .read(notificationPrefsProvider.notifier)
                  .setLeadMinutes(s.first),
            ),
          ],
          // Solo tiene sentido con una cuenta real (el invitado no tiene
          // contraseña que guardar) y en un dispositivo capaz de verificar.
          if (!(user?.isGuest ?? true) && bioDisponible) ...[
            const SizedBox(height: 28),
            Text('Seguridad', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: bio.enabled,
              onChanged: (v) => v
                  ? showBiometricEnableSheet(
                      context,
                      ref,
                      email: user?.email ?? '',
                      kind: bioKind,
                    )
                  : _desactivarAccesoRapido(context, ref),
              secondary: Icon(biometricIcon(bioKind)),
              title: Text('Entrar con ${biometricLabel(bioKind)}'),
              subtitle: Text(
                bio.enabled
                    ? 'Activado para ${bio.email}'
                    : 'Entra sin escribir tu contraseña',
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text('Apariencia', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(PhosphorIconsRegular.deviceMobile), label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(PhosphorIconsRegular.sun), label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(PhosphorIconsRegular.moon), label: Text('Oscuro')),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 28),
          Text('Acerca de', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _infoRow(context, 'Evento', OvumEvent.edition),
          _infoRow(context, 'Sede', OvumEvent.mainVenue),
          _infoRow(context, 'Organizan', OvumEvent.organizers),
          _infoRow(context, 'Versión', '1.0.0'),
          const SizedBox(height: 28),
          FilledButton.tonalIcon(
            // Se espera a que `logout()` termine antes de navegar: si no, el
            // estado de auth todavía es válido cuando el router evalúa /login
            // y el `redirect` rebota de vuelta a /home, dejando la app sin
            // sesión pero fuera de la pantalla de acceso.
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go(R.login);
            },
            icon: const Icon(PhosphorIconsRegular.signOut, size: 18),
            label: const Text(AppStrings.logout),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// Apaga el acceso rápido y borra las credenciales. Sin confirmación: es
  /// reversible en dos toques.
  Future<void> _desactivarAccesoRapido(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(biometricPrefsProvider.notifier).disable();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Acceso rápido desactivado.')),
    );
  }

  Widget _userCard(BuildContext context, String name, String position, String company,
      String email, String? photo) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6C453), BrandColors.yolk, BrandColors.sunrise],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(shape: BoxShape.circle),
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: InitialsAvatar(name: name, imageUrl: photo, size: 64),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                if (position.isNotEmpty || company.isNotEmpty)
                  Text(
                    [position, company].where((e) => e.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                if (email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ),
              ],
            ),
          ),
          Icon(PhosphorIconsRegular.identificationCard, color: Colors.white.withValues(alpha: 0.85)),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    final scheme = context.scheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
