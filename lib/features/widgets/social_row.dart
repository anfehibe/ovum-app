import 'package:flutter/material.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/utils/launchers.dart';
import '../../data/models/models.dart';

/// Fila de chips de redes sociales / web. Abre cada enlace con url_launcher.
class SocialRow extends StatelessWidget {
  const SocialRow({super.key, required this.socials});

  final SocialLinks socials;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (_has(socials.linkedin))
        _chip(PhosphorIconsFill.linkedinLogo, const Color(0xFF0077B5), socials.linkedin!),
      if (_has(socials.instagram))
        _chip(PhosphorIconsFill.instagramLogo, const Color(0xFFE4405F), socials.instagram!),
      if (_has(socials.twitter))
        _chip(PhosphorIconsFill.xLogo, const Color(0xFF14171A), socials.twitter!),
      if (_has(socials.facebook))
        _chip(PhosphorIconsFill.facebookLogo, const Color(0xFF1877F2), socials.facebook!),
      if (_has(socials.web))
        _chip(PhosphorIconsRegular.globe, const Color(0xFF3A9E7E), socials.web!),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 10, children: chips);
  }

  bool _has(String? v) => v != null && v.isNotEmpty;

  Widget _chip(IconData icon, Color color, String url) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openUrl(url),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
