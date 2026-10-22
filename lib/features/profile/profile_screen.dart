import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/auth/biometric_service.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/launchers.dart';
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
    final l10n = context.l10n;
    // Idioma efectivo para marcar el selector: la elección guardada, o el que
    // resolvió `MaterialApp` a partir del dispositivo cuando no hay elección.
    final currentLang =
        ref.watch(localeProvider)?.languageCode ?? Localizations.localeOf(context).languageCode;
    final favCount = ref.watch(favoritesProvider).length;
    final notif = ref.watch(notificationPrefsProvider);
    final bio = ref.watch(biometricPrefsProvider);
    final bioDisponible =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final bioKind =
        ref.watch(biometricKindProvider).valueOrNull ?? BiometricKind.fingerprint;
    final scheme = context.scheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _userCard(context, user?.name ?? l10n.profileGuest, user?.position ?? '', user?.company ?? '',
              user?.email ?? '', user?.photoUrl),
          // Vuelve a estar: `PUT /me` existe y está desplegado desde el
          // 2026-09-24, así que ahora guarda de verdad en el servidor.
          // Un invitado no tiene perfil que editar.
          if (!(user?.isGuest ?? true)) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push(R.profileEdit),
              icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
              label: Text(l10n.profileEditProfile),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ],
          const SizedBox(height: 24),
          _tile(
            context,
            icon: PhosphorIconsRegular.heart,
            title: l10n.favorites,
            subtitle: favCount == 0 ? l10n.profileNoFavoritesYet : l10n.profileSavedCount(favCount),
            onTap: () => context.push(R.favorites),
          ),
          if (!(user?.isGuest ?? true)) ...[
            const SizedBox(height: 10),
            _tile(
              context,
              icon: PhosphorIconsRegular.identificationCard,
              title: l10n.profileMyNetworkingProfile,
              subtitle: l10n.profileNetworkingSubtitle,
              onTap: () => context.push(R.networkingProfile),
            ),
          ],
          const SizedBox(height: 24),
          Text(l10n.profileNotifications, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: notif.pushEnabled,
            onChanged: (v) =>
                ref.read(notificationPrefsProvider.notifier).setPush(v),
            secondary: const Icon(PhosphorIconsRegular.bellRinging),
            title: Text(l10n.profileCongressAlerts),
            subtitle: Text(l10n.profileCongressAlertsSubtitle),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: notif.remindersEnabled,
            onChanged: (v) =>
                ref.read(notificationPrefsProvider.notifier).setReminders(v),
            secondary: const Icon(PhosphorIconsRegular.clockCountdown),
            title: Text(l10n.profileRememberSessions),
            subtitle: Text(l10n.profileRememberSessionsSubtitle),
          ),
          if (notif.remindersEnabled) ...[
            const SizedBox(height: 8),
            Text(
              l10n.profileRemindMeAhead,
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
            Text(l10n.profileSecurity, style: Theme.of(context).textTheme.titleMedium),
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
              title: Text(l10n.authLoginWith(biometricLabel(l10n, bioKind))),
              subtitle: Text(
                bio.enabled
                    ? l10n.profileEnabledFor(bio.email)
                    : l10n.profileLoginWithoutPassword,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(l10n.appearance, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, icon: const Icon(PhosphorIconsRegular.deviceMobile), label: Text(l10n.themeAuto)),
              ButtonSegment(value: ThemeMode.light, icon: const Icon(PhosphorIconsRegular.sun), label: Text(l10n.themeLight)),
              ButtonSegment(value: ThemeMode.dark, icon: const Icon(PhosphorIconsRegular.moon), label: Text(l10n.themeDark)),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 16),
          Text(l10n.language, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'es', icon: const Icon(PhosphorIconsRegular.globe), label: Text(l10n.languageSpanish)),
              ButtonSegment(value: 'en', icon: const Icon(PhosphorIconsRegular.globe), label: Text(l10n.languageEnglish)),
            ],
            selected: {currentLang == 'en' ? 'en' : 'es'},
            onSelectionChanged: (s) =>
                ref.read(localeProvider.notifier).set(Locale(s.first)),
          ),
          const SizedBox(height: 28),
          Text(l10n.profileAbout, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _infoRow(context, l10n.profileEventLabel, OvumEvent.edition),
          _infoRow(context, l10n.venue, OvumEvent.mainVenue),
          _infoRow(context, l10n.profileOrganizedBy, OvumEvent.organizers),
          _infoRow(context, l10n.profileVersionLabel, '1.0.0'),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: PhosphorIconsRegular.shieldCheck,
            title: l10n.profilePrivacyPolicy,
            subtitle: l10n.profilePrivacyPolicySubtitle,
            onTap: () => openUrl(AppConfig.privacyUrl),
          ),
          const SizedBox(height: 10),
          _tile(
            context,
            icon: PhosphorIconsRegular.fileText,
            title: l10n.profileTerms,
            subtitle: l10n.profileTermsSubtitle,
            onTap: () => openUrl(AppConfig.termsUrl),
          ),
          const SizedBox(height: 10),
          _tile(
            context,
            icon: PhosphorIconsRegular.envelopeSimple,
            title: l10n.profileContact,
            subtitle: OvumEvent.contactEmail,
            onTap: () => openEmail(OvumEvent.contactEmail),
          ),
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
            label: Text(l10n.logout),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
            ),
          ),
          // App Store exige poder eliminar la cuenta desde la app. El invitado
          // no tiene cuenta que borrar.
          if (!(user?.isGuest ?? true)) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push(R.deleteAccount),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: Text(l10n.profileDeleteMyAccount),
            ),
          ],
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
      SnackBar(content: Text(context.l10n.profileQuickAccessDisabled)),
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
            child: InitialsAvatar(name: name, imageUrl: photo, size: 64, zoomable: true),
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
