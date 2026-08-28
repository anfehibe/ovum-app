import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'preferences.dart';

// ── Tema (claro / oscuro / sistema), persistido ────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }

  void toggle() => set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ── Sesión de usuario (mock) ────────────────────────────────────────────────

/// Controla el usuario logueado. `null` = sin sesión (se muestra el login).
class AuthController extends Notifier<AppUser?> {
  static const _loggedKey = 'logged_in';
  static const _nameKey = 'user_name';
  static const _emailKey = 'user_email';

  @override
  AppUser? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs.getBool(_loggedKey) != true) return null;
    return AppUser.guest.copyWith(
      name: prefs.getString(_nameKey) ?? AppUser.guest.name,
      email: prefs.getString(_emailKey) ?? '',
    );
  }

  void loginAsGuest() => _login(AppUser.guest);

  void loginWithEmail(String email) {
    final name = _nameFromEmail(email);
    _login(AppUser.guest.copyWith(name: name, email: email));
  }

  void _login(AppUser user) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_loggedKey, true);
    prefs.setString(_nameKey, user.name);
    prefs.setString(_emailKey, user.email);
    state = user;
  }

  void updateUser(AppUser user) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_nameKey, user.name);
    prefs.setString(_emailKey, user.email);
    state = user;
  }

  void logout() {
    ref.read(sharedPreferencesProvider).setBool(_loggedKey, false);
    state = null;
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._]'), ' ').trim();
    if (local.isEmpty) return AppUser.guest.name;
    return local
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AppUser?>(AuthController.new);

/// Usuario actual (o null si no hay sesión).
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider));

final isLoggedInProvider = Provider<bool>((ref) => ref.watch(authControllerProvider) != null);
