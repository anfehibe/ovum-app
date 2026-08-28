import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences.dart';

/// Tipos de entidad que se pueden marcar como favoritos.
enum FavKind { session, speaker, sponsor, attendee, exhibitor }

String favKey(FavKind kind, String id) => '${kind.name}:$id';

/// Conjunto de favoritos (transversal), persistido en SharedPreferences.
class FavoritesNotifier extends Notifier<Set<String>> {
  static const _key = 'favorites';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getStringList(_key)?.toSet() ?? <String>{};
  }

  void toggle(FavKind kind, String id) {
    final key = favKey(kind, id);
    final next = {...state};
    if (!next.add(key)) next.remove(key);
    state = next;
    ref.read(sharedPreferencesProvider).setStringList(_key, next.toList());
  }

  bool contains(FavKind kind, String id) => state.contains(favKey(kind, id));
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

/// Conveniencia: ¿está marcado este (kind, id)?
final isFavoriteProvider = Provider.family<bool, ({FavKind kind, String id})>((ref, arg) {
  final favs = ref.watch(favoritesProvider);
  return favs.contains(favKey(arg.kind, arg.id));
});
