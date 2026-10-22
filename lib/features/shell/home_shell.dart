import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

/// Contenedor con la barra de navegación inferior (4 pestañas).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.houseSimple),
            selectedIcon: const Icon(PhosphorIconsFill.houseSimple),
            label: context.l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.calendarDots),
            selectedIcon: const Icon(PhosphorIconsFill.calendarDots),
            label: context.l10n.navAgenda,
          ),
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.usersThree),
            selectedIcon: const Icon(PhosphorIconsFill.usersThree),
            label: context.l10n.navNetworking,
          ),
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.user),
            selectedIcon: const Icon(PhosphorIconsFill.user),
            label: context.l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
