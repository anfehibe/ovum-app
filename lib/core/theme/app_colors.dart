import 'package:flutter/material.dart';

/// Paleta de marca OVUM — dirección "Cálida huevo / amanecer".
/// Ámbar/yema + terracota + jade, con acentos textiles guatemaltecos.
abstract final class BrandColors {
  // Semilla principal (yema / marigold)
  static const Color yolk = Color(0xFFE8991C);
  static const Color yolkDark = Color(0xFFF2A730);

  // Acentos base
  static const Color sunrise = Color(0xFFE4572E); // terracota / amanecer
  static const Color jade = Color(0xFF1EA896); // verde guatemalteco

  // Neutros cálidos (light)
  static const Color cream = Color(0xFFFBF6EE);
  static const Color warmInk = Color(0xFF2A2118);

  // Neutros cálidos (dark)
  static const Color nightBg = Color(0xFF17130D);
  static const Color nightSurface = Color(0xFF211B12);
}

/// Acentos de categoría (tracks/etiquetas) inspirados en el textil guatemalteco.
/// Se exponen como [ThemeExtension] para variar entre claro/oscuro.
@immutable
class OvumColors extends ThemeExtension<OvumColors> {
  const OvumColors({
    required this.categoryColors,
    required this.success,
    required this.warning,
    required this.info,
  });

  final List<Color> categoryColors;
  final Color success;
  final Color warning;
  final Color info;

  Color categoryAt(int index) =>
      categoryColors[index % categoryColors.length];

  static const OvumColors light = OvumColors(
    categoryColors: [
      Color(0xFF1EA896), // turquesa
      Color(0xFFD81E5B), // magenta
      Color(0xFFF2A007), // marigold
      Color(0xFF3D348B), // índigo
      Color(0xFF5A9E3F), // verde
      Color(0xFFE4572E), // coral
    ],
    success: Color(0xFF2E9E4F),
    warning: Color(0xFFE8991C),
    info: Color(0xFF2F80D8),
  );

  static const OvumColors dark = OvumColors(
    categoryColors: [
      Color(0xFF3FC5B3),
      Color(0xFFF25287),
      Color(0xFFF7B733),
      Color(0xFF9A93E0),
      Color(0xFF86C46B),
      Color(0xFFF07B57),
    ],
    success: Color(0xFF6FD08C),
    warning: Color(0xFFF2A730),
    info: Color(0xFF6FB0F0),
  );

  @override
  OvumColors copyWith({
    List<Color>? categoryColors,
    Color? success,
    Color? warning,
    Color? info,
  }) {
    return OvumColors(
      categoryColors: categoryColors ?? this.categoryColors,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  OvumColors lerp(ThemeExtension<OvumColors>? other, double t) {
    if (other is! OvumColors) return this;
    return OvumColors(
      categoryColors: [
        for (var i = 0; i < categoryColors.length; i++)
          Color.lerp(categoryColors[i], other.categoryColors[i], t)!,
      ],
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Acceso conveniente a [OvumColors] desde el contexto.
extension OvumColorsX on BuildContext {
  OvumColors get ovum => Theme.of(this).extension<OvumColors>() ?? OvumColors.light;
  ColorScheme get scheme => Theme.of(this).colorScheme;
}
