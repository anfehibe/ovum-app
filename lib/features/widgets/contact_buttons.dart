import 'package:flutter/material.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/utils/launchers.dart';

/// Fila de botones de contacto (web / correo / teléfono) para sponsors y expositores.
class ContactButtons extends StatelessWidget {
  const ContactButtons({super.key, this.web, this.email, this.phone});

  final String? web;
  final String? email;
  final String? phone;

  bool _has(String? v) => v != null && v.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (_has(web))
        _button(PhosphorIconsRegular.globe, context.l10n.website, () => openUrl(web!)),
      if (_has(email))
        _button(PhosphorIconsRegular.envelopeSimple, context.l10n.email, () => openEmail(email!)),
      if (_has(phone))
        _button(PhosphorIconsRegular.phone, context.l10n.call, () => openPhone(phone!)),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  Widget _button(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
    );
  }
}
