import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/iterable_ext.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ovum_logo.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/user_provider.dart';

/// Splash de arranque: muestra la imagen `orden 1` del API `/app/splash` durante
/// 3 segundos y luego navega al login (o al home si ya hay sesión). Reemplaza al
/// native splash, que ahora es solo un fondo de marca instantáneo.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _duration = Duration(seconds: 3);
  Timer? _timer;
  bool _precachedBanner = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_duration, _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goNext() {
    if (!mounted) return;
    final loggedIn = ref.read(isLoggedInProvider);
    context.go(loggedIn ? R.home : R.login);
  }

  @override
  Widget build(BuildContext context) {
    final splashes =
        ref.watch(splashProvider).valueOrNull ?? const <SplashItem>[];

    // Precarga el banner (order:2) para que el header de login/home aparezca al instante.
    if (!_precachedBanner) {
      final banner = splashes.firstWhereOrNull((s) => s.order == 2)?.imageUrl;
      if (banner != null && banner.isNotEmpty) {
        _precachedBanner = true;
        precacheImage(CachedNetworkImageProvider(banner), context);
      }
    }

    final item = splashes.firstWhereOrNull((s) => s.order == 1) ??
        (splashes.isNotEmpty ? splashes.first : null);
    final imageUrl = item?.imageUrl;

    Widget content;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      content = CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const _BrandFallback(),
      );
    } else {
      content = const _BrandFallback();
    }

    final link = item?.link;
    if (link != null && link.isNotEmpty) {
      content = GestureDetector(onTap: () => openUrl(link), child: content);
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6C453), BrandColors.yolk, BrandColors.sunrise],
          ),
        ),
        child: SizedBox.expand(child: content),
      ),
    );
  }
}

/// Respaldo de marca cuando no hay imagen de splash (API vacío o error).
class _BrandFallback extends StatelessWidget {
  const _BrandFallback();

  @override
  Widget build(BuildContext context) =>
      const Center(child: OvumEggMark(size: 96, onDark: true));
}
