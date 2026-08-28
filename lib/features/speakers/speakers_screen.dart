import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';

class SpeakersScreen extends ConsumerStatefulWidget {
  const SpeakersScreen({super.key});

  @override
  ConsumerState<SpeakersScreen> createState() => _SpeakersScreenState();
}

class _SpeakersScreenState extends ConsumerState<SpeakersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(speakersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.speakers)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (speakers) {
          final filtered = speakers.where((s) {
            final q = _query.toLowerCase();
            return q.isEmpty ||
                s.name.toLowerCase().contains(q) ||
                s.company.toLowerCase().contains(q) ||
                s.role.toLowerCase().contains(q);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar conferencista',
                    prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(message: 'Sin resultados')
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _SpeakerCard(speaker: filtered[i])
                            .animate()
                            .fadeIn(delay: (30 * i).ms),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpeakerCard extends StatelessWidget {
  const _SpeakerCard({required this.speaker});
  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.speaker(speaker.id)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  InitialsAvatar(name: speaker.name, imageUrl: speaker.photoUrl, size: 74),
                  if (speaker.isKeynote)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surfaceContainerLow, width: 2),
                        ),
                        child: const Icon(PhosphorIconsFill.star, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                speaker.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                speaker.role,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.primary),
              ),
              const Spacer(),
              Text(
                speaker.company,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
