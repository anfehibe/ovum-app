import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/networking_provider.dart';
import '../widgets/networking_card_tile.dart';
import 'networking_tab_error.dart';

/// Directorio de asistentes con búsqueda (debounced en el provider), filtro por
/// sector y paginación por centinela al final de la lista.
class DirectoryTab extends ConsumerStatefulWidget {
  const DirectoryTab({super.key});

  @override
  ConsumerState<DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends ConsumerState<DirectoryTab> {
  final _searchCtrl = TextEditingController();
  final _chipsCtrl = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _chipsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(directoryProvider.notifier).loadMore();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar más asistentes.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(directoryProvider);
    final query = ref.watch(directoryQueryProvider);
    final sectors = ref.watch(networkingCatalogProvider).valueOrNull?.sectors ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              setState(() {}); // refresca el botón de limpiar
              ref.read(directoryQueryProvider.notifier).setSearch(v);
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, empresa o cargo',
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(PhosphorIconsRegular.x, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(directoryQueryProvider.notifier).setSearch('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        if (sectors.isNotEmpty)
          SizedBox(
            height: 44,
            child: EdgeFade(
              controller: _chipsCtrl,
              child: ListView(
                controller: _chipsCtrl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final s in sectors)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(s.es),
                        selected: query.sector == s.value,
                        onSelected: (selected) => ref
                            .read(directoryQueryProvider.notifier)
                            .setSector(selected ? s.value : null),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: async.when(
            loading: () => const LoadingView(),
            error: (e, _) => NetworkingTabError(error: e),
            data: (state) {
              if (state.items.isEmpty) {
                return const EmptyState(
                  message: 'Sin resultados',
                  icon: PhosphorIconsRegular.usersThree,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: state.items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == state.items.length) return _footer(state);
                  final card = state.items[i];
                  return NetworkingCardTile(
                    card: card,
                    onTap: () => context.push(R.networkingAttendee(card.id)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Centinela: al construirse pide la página siguiente. El notifier ignora las
  /// llamadas repetidas mientras hay una en vuelo.
  Widget _footer(DirectoryState state) {
    if (state.page >= state.lastPage) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Center(
          child: Text(
            state.total == 1 ? '1 asistente' : '${state.total} asistentes',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
