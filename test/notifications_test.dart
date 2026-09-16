import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/core/notifications/notification_routes.dart';
import 'package:ovum/core/notifications/session_reminders.dart';
import 'package:ovum/core/router/route_paths.dart';
import 'package:ovum/core/utils/date_ext.dart';

void main() {
  group('resolveNotificationRoute', () {
    test('el payload real de hoy no produce ruta', () {
      // El panel de TRIVVO solo manda {"origen":"panel"}: el tap abre la app.
      expect(resolveNotificationRoute({'origen': 'panel'}), isNull);
    });

    test('sin tipo o sin id devuelve null', () {
      expect(resolveNotificationRoute({}), isNull);
      expect(resolveNotificationRoute({'tipo': 'sesion'}), isNull);
      expect(resolveNotificationRoute({'id': '12'}), isNull);
      expect(resolveNotificationRoute({'tipo': 'sesion', 'id': ''}), isNull);
    });

    test('mapea tipo + id a la ruta correspondiente', () {
      expect(
        resolveNotificationRoute({'tipo': 'sesion', 'id': '12'}),
        R.session('12'),
      );
      expect(
        resolveNotificationRoute({'type': 'speaker', 'id': '7'}),
        R.speaker('7'),
      );
      expect(
        resolveNotificationRoute({'tipo': 'ENCUESTA', 'id': '3'}),
        R.pollsFor('3'),
      );
    });

    test('acepta ids numéricos y un tipo desconocido cae en null', () {
      expect(resolveNotificationRoute({'tipo': 'sesion', 'id': 12}), R.session('12'));
      expect(resolveNotificationRoute({'tipo': 'marciano', 'id': '1'}), isNull);
    });

    test('una ruta explícita gana sobre tipo/id', () {
      expect(
        resolveNotificationRoute({'ruta': '/hotels', 'tipo': 'sesion', 'id': '9'}),
        '/hotels',
      );
      // Una ruta que no empieza por "/" se ignora.
      expect(resolveNotificationRoute({'ruta': 'javascript:x'}), isNull);
    });

    test('un chat abre el hilo del remitente', () {
      expect(
        resolveNotificationRoute({'tipo': 'chat', 'id': '28169'}),
        R.chatWith('28169'),
      );
      expect(
        resolveNotificationRoute({'type': 'message', 'entity_id': 28169}),
        R.chatWith('28169'),
      );
    });

    test('una reunión aterriza en networking (no hay ruta por reunión)', () {
      expect(resolveNotificationRoute({'tipo': 'reunion', 'id': '5'}), R.networking);
    });
  });

  group('chatCounterpartId', () {
    test('devuelve el id solo para las push de mensaje', () {
      expect(chatCounterpartId({'tipo': 'chat', 'id': '28169'}), '28169');
      expect(chatCounterpartId({'tipo': 'MENSAJE', 'id': 28169}), '28169');
      expect(chatCounterpartId({'type': 'message', 'entity_id': '7'}), '7');
    });

    test('null para cualquier otra push', () {
      expect(chatCounterpartId({'origen': 'panel'}), isNull);
      expect(chatCounterpartId({'tipo': 'sesion', 'id': '12'}), isNull);
      expect(chatCounterpartId({}), isNull);
    });

    test('null si el tipo es de chat pero falta el interlocutor', () {
      expect(chatCounterpartId({'tipo': 'chat'}), isNull);
      expect(chatCounterpartId({'tipo': 'chat', 'id': ''}), isNull);
    });
  });

  group('reminderIdFor', () {
    test('es determinista', () {
      expect(reminderIdFor('1203'), reminderIdFor('1203'));
    });

    test('siempre es positivo y cabe en un int de 32 bits', () {
      for (final id in ['1', '1203', 'mock-session-a', '', '99999999999']) {
        final value = reminderIdFor(id);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThanOrEqualTo(0x7fffffff));
      }
    });

    test('ids distintos no colisionan', () {
      final ids = List.generate(500, (i) => '$i');
      expect(ids.map(reminderIdFor).toSet().length, ids.length);
    });
  });

  group('wallClock', () {
    test('conserva los componentes que muestra la agenda', () {
      // El API manda 08:00-05:00; DateTime.tryParse da el instante UTC 13:00Z,
      // y la app lo muestra como "13:00" (formatea sin toLocal). El
      // recordatorio debe partir de esos mismos componentes.
      final delApi = DateTime.parse('2026-11-11T08:00:00-05:00');
      expect(delApi.isUtc, isTrue);
      expect(delApi.hour, 13);

      final wall = wallClock(delApi);
      expect(wall.isUtc, isFalse);
      expect(wall.year, 2026);
      expect(wall.month, 11);
      expect(wall.day, 11);
      expect(wall.hour, 13);
      expect(wall.minute, 0);
    });

    test('con 15 min de antelación el aviso cae a las 12:45 de pared', () {
      final wall = wallClock(DateTime.parse('2026-11-11T08:00:00-05:00'));
      final aviso = wall.subtract(const Duration(minutes: 15));
      expect(aviso.hour, 12);
      expect(aviso.minute, 45);
      expect(aviso.day, 11);
    });
  });
}
