import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/sign_in_prompt.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/networking_provider.dart';
import 'directory_tab.dart';
import 'favorites_tab.dart';
import 'meetings_tab.dart';

/// Networking del congreso.
///
/// Todo el módulo está detrás de una compuerta: el backend responde 403 si el
/// organizador no abrió el networking o si el usuario no es asistente confirmado,
/// y **no hay endpoint que informe ese estado**, así que se sondea con
/// `GET /networking/me`. Cuando está cerrado no se deja al usuario en un callejón
/// sin salida: se muestra el motivo y, debajo, el listado de asistentes de solo
/// lectura (ese endpoint no tiene guard de networking).
class NetworkingScreen extends ConsumerWidget {
  const NetworkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(networkingAccessProvider);
    return access.when(
      loading: () => const _Shell(child: LoadingView()),
      error: (_, _) => _Shell(child: _retry(context, ref, null)),
      data: (a) {
        if (a.isOpen) return const _Tabs();
        return switch (a.block!) {
          NetworkingBlock.signInRequired => const _Shell(
            child: SignInPrompt(
              message: 'Inicia sesión para hacer networking con otros asistentes.',
            ),
          ),
          NetworkingBlock.failed => _Shell(child: _retry(context, ref, a.message)),
          NetworkingBlock.closed ||
          NetworkingBlock.disabled => _Shell(child: _Degraded(message: a.message)),
        };
      },
    );
  }

  Widget _retry(BuildContext context, WidgetRef ref, String? message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ErrorView(message: message),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => ref.invalidate(networkingAccessProvider),
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}

/// Andamio común (AppBar + accesos) para los estados sin pestañas.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navNetworking),
        actions: [
          IconButton(
            tooltip: 'Mis chats',
            icon: const Icon(PhosphorIconsRegular.chatsCircle),
            onPressed: () => context.push(R.chats),
          ),
        ],
      ),
      body: child,
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.navNetworking),
          actions: [
            IconButton(
              tooltip: 'Mi perfil de networking',
              icon: const Icon(PhosphorIconsRegular.identificationCard),
              onPressed: () => context.push(R.networkingProfile),
            ),
            IconButton(
              tooltip: 'Mis chats',
              icon: const Icon(PhosphorIconsRegular.chatsCircle),
              onPressed: () => context.push(R.chats),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Directorio'),
              Tab(text: 'Favoritos'),
              Tab(text: 'Reuniones'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [DirectoryTab(), FavoritesTab(), MeetingsTab()],
        ),
      ),
    );
  }
}

/// Networking cerrado: se explica por qué y se ofrece el roster de asistentes,
/// que sigue disponible porque `/events/{id}/attendees` solo exige sesión.
class _Degraded extends ConsumerWidget {
  const _Degraded({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final async = ref.watch(attendeesProvider);

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(PhosphorIconsRegular.info, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message.isEmpty
                      ? 'El networking no está disponible para este evento.'
                      : message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const LoadingView(),
            error: (_, _) => const ErrorView(),
            data: (attendees) => attendees.isEmpty
                ? const EmptyState(
                    message: 'Todavía no hay asistentes publicados.',
                    icon: PhosphorIconsRegular.usersThree,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: attendees.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _AttendeeRow(attendee: attendees[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({required this.attendee});
  final Attendee attendee;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final subtitle = [
      attendee.position,
      attendee.company,
    ].where((p) => p.trim().isNotEmpty).join(' · ');

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.attendee(attendee.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              InitialsAvatar(
                name: attendee.name,
                imageUrl: attendee.photoUrl,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attendee.name, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
