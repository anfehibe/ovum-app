import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';

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
        destinations: const [
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.houseSimple),
            selectedIcon: Icon(PhosphorIconsFill.houseSimple),
            label: AppStrings.navHome,
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.calendarDots),
            selectedIcon: Icon(PhosphorIconsFill.calendarDots),
            label: AppStrings.navAgenda,
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.usersThree),
            selectedIcon: Icon(PhosphorIconsFill.usersThree),
            label: AppStrings.navNetworking,
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.user),
            selectedIcon: Icon(PhosphorIconsFill.user),
            label: AppStrings.navProfile,
          ),
        ],
      ),
    );
  }
}
