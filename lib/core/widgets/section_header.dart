import 'package:flutter/material.dart';

import '../constants/app_strings.dart';

/// Encabezado de sección con título y acción opcional ("Ver todo").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel ?? AppStrings.seeAll),
            ),
        ],
      ),
    );
  }
}
