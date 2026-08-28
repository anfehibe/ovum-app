import 'package:flutter/widgets.dart';
import 'package:ovum/core/ui/app_icons.dart';

/// Resuelve la clave de ícono de un [InfoItem] al ícono Phosphor correspondiente.
IconData infoIcon(String key) => switch (key) {
      'airplane' => PhosphorIconsRegular.airplane,
      'passport' => PhosphorIconsRegular.identificationCard,
      'map' => PhosphorIconsRegular.mapTrifold,
      'compass' => PhosphorIconsRegular.compass,
      'mail' => PhosphorIconsRegular.envelopeSimple,
      'phone' => PhosphorIconsRegular.phone,
      'globe' => PhosphorIconsRegular.globe,
      _ => PhosphorIconsRegular.info,
    };
