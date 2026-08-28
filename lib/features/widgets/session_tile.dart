import 'package:flutter/material.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/category_chip.dart';
import '../../data/models/models.dart';

/// Tarjeta de sesión con barra de acento por track, horario y título.
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session, this.onTap, this.trailing});

  final Session session;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final color = trackColor(context, session.track);
    final subtitle = session.shortDescription.isNotEmpty
        ? session.shortDescription
        : session.room;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIconsRegular.clock, size: 14, color: color),
                            const SizedBox(width: 6),
                            Text(
                              timeRange(session.startDate, session.endDate),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            CategoryChip(label: session.track),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          session.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(PhosphorIconsRegular.mapPin,
                                  size: 13, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (trailing != null)
                  Padding(padding: const EdgeInsets.only(right: 6), child: Center(child: trailing))
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(PhosphorIconsRegular.caretRight,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
