import 'package:flutter/material.dart';

/// Desvanece el contenido contra el borde por el que todavía queda algo por
/// ver. Sirve como pista de que una lista horizontal se puede deslizar.
///
/// El degradado aparece sólo del lado donde hay scroll disponible, así que al
/// llegar a un extremo ese borde queda nítido.
class EdgeFade extends StatelessWidget {
  const EdgeFade({
    super.key,
    required this.controller,
    required this.child,
    this.extent = 28,
  });

  /// Controller de la lista envuelta; debe ser el mismo que usa [child].
  final ScrollController controller;

  /// Ancho (en px lógicos) de la franja de desvanecido.
  final double extent;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pos = controller.hasClients ? controller.position : null;
        final before = pos == null
            ? 0.0
            : ((pos.pixels - pos.minScrollExtent) / extent).clamp(0.0, 1.0);
        final after = pos == null
            ? 0.0
            : ((pos.maxScrollExtent - pos.pixels) / extent).clamp(0.0, 1.0);

        // Sin nada que desvanecer evitamos el saveLayer del ShaderMask.
        if (before == 0 && after == 0) return child!;

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final f = (extent / rect.width).clamp(0.0, 0.5);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0, before * f, 1 - after * f, 1],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: child,
    );
  }
}
