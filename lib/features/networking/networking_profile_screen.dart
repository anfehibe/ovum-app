import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/states.dart';
import '../../data/models/networking_catalog.dart';
import '../../data/providers/networking_provider.dart';

/// Editor del perfil de networking propio.
///
/// Los topes (3 sectores / 7 intereses) se aplican **en la UI**: el servidor
/// trunca en silencio, y alguien que elige cinco y recibe tres sin explicación
/// reporta un bug con razón.
class NetworkingProfileScreen extends ConsumerStatefulWidget {
  const NetworkingProfileScreen({super.key});

  @override
  ConsumerState<NetworkingProfileScreen> createState() =>
      _NetworkingProfileScreenState();
}

class _NetworkingProfileScreenState
    extends ConsumerState<NetworkingProfileScreen> {
  Set<String> _sectors = {};
  Set<String> _interests = {};
  Set<String> _seeking = {};
  Set<String> _solutions = {};
  Set<String> _regions = {};

  bool _seeded = false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final message = await ref
          .read(myNetworkingProfileProvider.notifier)
          .save(
            sectors: _sectors.toList(),
            interests: _interests.toList(),
            seeking: _seeking.toList(),
            solutions: _solutions.toList(),
            regions: _regions.toList(),
          );
      if (!mounted) return;
      // El PUT no escribe sectores/intereses si el usuario no tiene ficha base;
      // se detecta releyendo: mandamos algo y volvió vacío.
      final saved = ref.read(myNetworkingProfileProvider).valueOrNull;
      final silentlyDropped =
          (_sectors.isNotEmpty || _interests.isNotEmpty) &&
          (saved?.sectors.isEmpty ?? true) &&
          (saved?.interests.isEmpty ?? true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            silentlyDropped
                ? 'Tu perfil del congreso está incompleto: completa tu registro '
                      'para poder guardar sectores e intereses.'
                : message,
          ),
        ),
      );
      if (!silentlyDropped) navigator.pop();
    } on ApiException catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el perfil.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(networkingCatalogProvider);
    final profile = ref.watch(myNetworkingProfileProvider).valueOrNull;

    // Siembra inicial desde el perfil del servidor (una sola vez).
    if (!_seeded && profile != null) {
      _seeded = true;
      _sectors = profile.sectors.toSet();
      _interests = profile.interests.toSet();
      _seeking = profile.seeking.toSet();
      _solutions = profile.solutions.toSet();
      _regions = profile.regions.toSet();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil de networking')),
      body: catalogAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e is ApiException ? e.message : null),
        data: (catalog) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Esto ayuda a que otros asistentes te encuentren en el directorio.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            _group(
              title: 'Mi sector',
              options: catalog.sectors,
              selected: _sectors,
              max: catalog.maxSectors,
              onChanged: (v) => setState(() => _sectors = v),
            ),
            _group(
              title: 'Mis intereses',
              options: catalog.interests,
              selected: _interests,
              max: catalog.maxInterests,
              onChanged: (v) => setState(() => _interests = v),
            ),
            _group(
              title: 'Estoy buscando',
              options: catalog.seeking,
              selected: _seeking,
              onChanged: (v) => setState(() => _seeking = v),
            ),
            _group(
              title: 'Ofrezco soluciones de',
              options: catalog.solutions,
              selected: _solutions,
              onChanged: (v) => setState(() => _solutions = v),
            ),
            _group(
              title: 'Regiones de interés',
              options: catalog.regions,
              selected: _regions,
              onChanged: (v) => setState(() => _regions = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group({
    required String title,
    required List<CatalogOption> options,
    required Set<String> selected,
    required void Function(Set<String>) onChanged,
    int? max,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();
    final atMax = max != null && selected.length >= max;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (max != null)
                Text(
                  '${selected.length}/$max',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: atMax
                        ? context.scheme.primary
                        : context.scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                FilterChip(
                  label: Text(o.es),
                  selected: selected.contains(o.value),
                  // Al llegar al tope se desactivan las no elegidas, en vez de
                  // dejar elegir y que el servidor recorte sin avisar.
                  onSelected: (!selected.contains(o.value) && atMax)
                      ? null
                      : (on) {
                          final next = {...selected};
                          on ? next.add(o.value) : next.remove(o.value);
                          onChanged(next);
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
