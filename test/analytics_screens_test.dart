import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/analytics/analytics.dart';

/// `topScreen` decide el nombre de pantalla que va a Analytics: tiene que ser
/// el patrón de la ruta (sin ids) y seguir a la pantalla de arriba tanto con
/// `go` como con `push`, al volver atrás y al cambiar de pestaña.
void main() {
  GoRouter build() => GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => shell,
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/home', builder: (_, _) => const Text('home')),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/agenda', builder: (_, _) => const Text('agenda')),
              ]),
            ],
          ),
          GoRoute(
            path: '/speaker/:id',
            builder: (_, s) => Text('speaker ${s.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/transport/route/:id/map',
            builder: (_, _) => const Text('map'),
          ),
        ],
      );

  testWidgets('patrón e id de la pantalla visible', (tester) async {
    final router = build();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    (String?, String?) top() =>
        topScreen(router.routerDelegate.currentConfiguration);

    expect(top(), ('/home', null));

    router.go('/agenda'); // cambio de pestaña
    await tester.pumpAndSettle();
    expect(top(), ('/agenda', null));

    router.push('/speaker/42'); // detalle apilado sobre el shell
    await tester.pumpAndSettle();
    expect(top(), ('/speaker/:id', '42'));

    router.push('/transport/route/7/map');
    await tester.pumpAndSettle();
    expect(top(), ('/transport/route/:id/map', '7'));

    router.pop();
    await tester.pumpAndSettle();
    expect(top(), ('/speaker/:id', '42'));

    router.pop();
    await tester.pumpAndSettle();
    expect(top(), ('/agenda', null));

    router.go('/speaker/9'); // deep link (push de notificación)
    await tester.pumpAndSettle();
    expect(top(), ('/speaker/:id', '9'));
  });
}
