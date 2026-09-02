import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/data/models/info_item.dart';
import 'package:ovum/data/models/sponsor.dart';
import 'package:ovum/data/repositories/mappers/attendee_mapper.dart';
import 'package:ovum/data/repositories/mappers/content_mapper.dart';
import 'package:ovum/data/repositories/mappers/poll_mapper.dart';
import 'package:ovum/data/repositories/mappers/session_mapper.dart';
import 'package:ovum/data/repositories/mappers/speaker_mapper.dart';
import 'package:ovum/data/repositories/mappers/sponsor_mapper.dart';
import 'package:ovum/data/repositories/mappers/user_mapper.dart';

void main() {
  group('sessionsFromAgendaJson', () {
    // Muestra con el contrato REAL de GET /events/{id}/agenda (EventController):
    // data[] = venues, cada uno con sesiones[] que embeben ponentes/sponsor/features.
    final venues = [
      {
        'id': 1,
        'nombre': 'Hotel X',
        'direccion': 'Zona 10',
        'lat': '14.6',
        'lng': '-90.5',
        'sesiones': [
          {
            'id': 10,
            'titulo': 'Apertura',
            'tipo': 'keynote',
            'sala': 'Salón A',
            'inicio': '2026-11-11T09:00:00-05:00',
            'fin': '2026-11-11T10:00:00-05:00',
            'descripcion': 'Bienvenida',
            'sponsor': {'nombre': 'ACME', 'logo': 'https://x/acme.png'},
            'ponentes': [
              {'id': 5, 'nombre': 'Ana', 'cargo': 'CEO', 'foto': 'https://x/ana.png'},
              {'id': 6, 'nombre': 'Beto', 'cargo': 'CTO', 'foto': null},
            ],
            'moderadores': [],
            'features': {'ponentes': true, 'qa': true},
          },
        ],
      },
    ];

    test('aplana venue→sesion y convierte ids int a String', () {
      final sessions = sessionsFromAgendaJson(venues);
      expect(sessions, hasLength(1));
      final s = sessions.first;
      expect(s.id, '10'); // int → String
      expect(s.title, 'Apertura'); // titulo → title
      expect(s.room, 'Salón A'); // sala → room
      expect(s.description, 'Bienvenida');
      expect(s.track, 'keynote'); // tipo → track
      expect(s.startDate, DateTime.parse('2026-11-11T09:00:00-05:00'));
      expect(s.endDate, DateTime.parse('2026-11-11T10:00:00-05:00'));
    });

    test('mapea ponentes embebidos a speakerIds', () {
      final s = sessionsFromAgendaJson(venues).first;
      expect(s.speakerIds, ['5', '6']);
    });

    test('mapea el sponsor y features.qa', () {
      final s = sessionsFromAgendaJson(venues).first;
      expect(s.sponsorName, 'ACME');
      expect(s.sponsorLogo, 'https://x/acme.png');
      expect(s.hasQuestions, isTrue); // features.qa
      expect(s.hasPolls, isFalse); // sin flag por sesión aún
      expect(s.isOtherActivity, isFalse);
    });

    test('usa el nombre de la sede como sala si la sesión no trae sala', () {
      final sinSala = [
        {
          'nombre': 'Auditorio',
          'sesiones': [
            {
              'id': 2,
              'titulo': 'Charla',
              'inicio': '2026-11-11T11:00:00-05:00',
              'fin': '2026-11-11T12:00:00-05:00',
            },
          ],
        },
      ];
      final s = sessionsFromAgendaJson(sinSala).first;
      expect(s.room, 'Auditorio');
      expect(s.speakerIds, isEmpty); // sin ponentes
      expect(s.sponsorName, isNull);
      expect(s.hasQuestions, isFalse);
    });

    test('descarta sesiones sin horario válido', () {
      final malo = [
        {
          'nombre': 'X',
          'sesiones': [
            {'id': 9, 'titulo': 'Sin fecha'},
          ],
        },
      ];
      expect(sessionsFromAgendaJson(malo), isEmpty);
    });
  });

  group('attendeeFromJson', () {
    test('une nombre+apellido y envuelve linkedin en socials', () {
      final a = attendeeFromJson({
        'id': 12,
        'nombre': 'Ana',
        'apellido': 'López',
        'foto': 'https://x/ana.jpg',
        'empresa': 'Banco Y',
        'cargo': 'Directora',
        'sector': 'Banca',
        'bio': 'Bio',
        'linkedin': 'https://linkedin.com/in/ana',
      });
      expect(a.id, '12');
      expect(a.name, 'Ana López');
      expect(a.position, 'Directora');
      expect(a.company, 'Banco Y');
      expect(a.photoUrl, 'https://x/ana.jpg');
      expect(a.sector, 'Banca');
      expect(a.socials.linkedin, 'https://linkedin.com/in/ana');
      // El API v1 no entrega estos → vacíos.
      expect(a.city, isEmpty);
      expect(a.country, isEmpty);
      expect(a.interests, isEmpty);
    });

    test('sin linkedin no marca socials', () {
      final a = attendeeFromJson({'id': 1, 'nombre': 'Solo'});
      expect(a.name, 'Solo');
      expect(a.socials.hasAny, isFalse);
    });

    test('normaliza foto relativa (placeholder) a null', () {
      final a = attendeeFromJson({'id': 1, 'nombre': 'X', 'foto': '/img/usuario.jpg'});
      expect(a.photoUrl, isNull);
    });
  });

  group('appUserFromApiJson', () {
    test('mapea el usuario del login y conserva ids de la API', () {
      final u = appUserFromApiJson({
        'id': 12,
        'nombre': 'Juan',
        'apellido': 'Pérez',
        'email': 'juan@empresa.com',
        'foto': 'https://x/u.jpg',
        'empresa': 'Banco X',
        'cargo': 'Gerente',
        'movil': '+502 5555',
        'ciudad': 'Guatemala',
        'pais_id': 320,
        'tenant_id': 3,
      });
      expect(u.id, '12');
      expect(u.name, 'Juan Pérez');
      expect(u.email, 'juan@empresa.com');
      expect(u.company, 'Banco X');
      expect(u.position, 'Gerente');
      expect(u.city, 'Guatemala');
      expect(u.mobile, '+502 5555');
      expect(u.countryId, 320);
      expect(u.tenantId, 3);
      expect(u.isGuest, isFalse);
    });

    test('cae al email como nombre si no hay nombre/apellido', () {
      final u = appUserFromApiJson({'id': 5, 'email': 'x@y.com'});
      expect(u.name, 'x@y.com');
    });

    test('normaliza foto relativa (placeholder) a null', () {
      final u = appUserFromApiJson({'id': 1, 'nombre': 'X', 'foto': '/img/usuario.jpg'});
      expect(u.photoUrl, isNull);
    });
  });

  group('speakerFromJson', () {
    test('mapea el ponente y sus redes (personPayload con detalle)', () {
      final s = speakerFromJson({
        'id': 7,
        'nombre': 'Dra. Ana',
        'cargo': 'Investigadora',
        'foto': 'https://x/ana.png',
        'bio': 'Experta en nutrición',
        'web': 'https://ana.com',
        'redes': [
          {'red': 'linkedin', 'link': 'https://linkedin.com/in/ana'},
          {'red': 'Twitter', 'link': 'https://twitter.com/ana'},
          {'red': 'desconocida', 'link': 'https://x/y'},
        ],
      });
      expect(s.id, '7');
      expect(s.name, 'Dra. Ana');
      expect(s.role, 'Investigadora'); // cargo → role
      expect(s.bio, 'Experta en nutrición');
      expect(s.photoUrl, 'https://x/ana.png');
      expect(s.socials.web, 'https://ana.com');
      expect(s.socials.linkedin, 'https://linkedin.com/in/ana');
      expect(s.socials.twitter, 'https://twitter.com/ana'); // case-insensitive
      // Gaps del API: sin empresa ni flag de keynote.
      expect(s.company, '');
      expect(s.isKeynote, isFalse);
    });

    test('normaliza foto relativa y tolera sin redes', () {
      final s = speakerFromJson({
        'id': 8,
        'nombre': 'Beto',
        'foto': '/img/usuario.jpg',
      });
      expect(s.photoUrl, isNull);
      expect(s.socials.hasAny, isFalse);
    });
  });

  group('sponsorFromJson', () {
    test('mapea nivel → tier y normaliza logo', () {
      final s = sponsorFromJson({
        'id': 3,
        'nombre': 'ACME',
        'logo': 'https://x/acme.png',
        'web': 'https://acme.com',
        'descripcion': 'Líder en avicultura',
        'nivel': 'oro',
        'tipo': 'general',
      });
      expect(s.id, '3');
      expect(s.name, 'ACME');
      expect(s.tier, SponsorTier.oro);
      expect(s.description, 'Líder en avicultura');
      expect(s.logoUrl, 'https://x/acme.png');
      expect(s.web, 'https://acme.com');
    });

    test('nivel desconocido cae a bronce; logo relativo → null', () {
      final s = sponsorFromJson({'id': 4, 'nombre': 'X', 'nivel': 'platino', 'logo': '/img/no_pic.jpg'});
      expect(s.tier, SponsorTier.bronce);
      expect(s.logoUrl, isNull);
    });
  });

  group('sessionsFromOtherActivitiesJson', () {
    test('mapea a Session con isOtherActivity=true', () {
      final s = sessionsFromOtherActivitiesJson([
        {
          'id': 20,
          'titulo': 'Cóctel',
          'tipo': 'social',
          'descripcion': 'Networking',
          'inicio': '2026-11-11T19:00:00-05:00',
          'fin': '2026-11-11T21:00:00-05:00',
          'imagen': 'https://x/coctel.jpg',
        },
      ]).first;
      expect(s.id, '20');
      expect(s.title, 'Cóctel'); // titulo → title
      expect(s.isOtherActivity, isTrue);
      expect(s.track, 'social');
      expect(s.imageUrl, 'https://x/coctel.jpg');
    });

    test('descarta actividades sin horario', () {
      final list = sessionsFromOtherActivitiesJson([
        {'id': 9, 'titulo': 'Sin fecha'},
      ]);
      expect(list, isEmpty);
    });
  });

  group('content mappers', () {
    test('organizerFromJson sintetiza id (el API no trae id)', () {
      final o = organizerFromJson({
        'name': 'ANAVI',
        'position': 'Anfitrión',
        'web': 'https://anavi.gt',
        'image': 'https://x/l.png',
      }, 0);
      expect(o.id, 'org-0'); // id sintético
      expect(o.name, 'ANAVI');
      expect(o.description, 'Anfitrión'); // position → description
      expect(o.logoUrl, 'https://x/l.png');
    });

    test('usa id real si el backend lo incluye (forward-compatible)', () {
      expect(organizerFromJson({'id': 99, 'name': 'X'}, 0).id, '99');
    });

    test('exhibitorFromJson mapea stand→booth, level→category', () {
      final e = exhibitorFromJson({
        'name': 'Stand X',
        'stand': 'A-12',
        'level': 'oro',
        'email': 'x@y.com',
        'image': '/img/no_pic.jpg',
      }, 2);
      expect(e.id, 'exh-2');
      expect(e.booth, 'A-12');
      expect(e.category, 'oro');
      expect(e.email, 'x@y.com');
      expect(e.logoUrl, isNull); // relativa → null
    });

    test('infoFromPhone arma acción de teléfono', () {
      final i = infoFromPhone({'name': 'Emergencias', 'phone': '+502 123', 'address': 'Zona 1'}, 0);
      expect(i.category, 'Contactos');
      expect(i.title, 'Emergencias');
      expect(i.body, 'Zona 1');
      expect(i.actionType, InfoActionType.phone);
      expect(i.actionValue, '+502 123');
    });

    test('infoFromInterest y infoFromService', () {
      expect(infoFromInterest({'title': 'Visas', 'content': 'Info'}, 0).body, 'Info');
      expect(infoFromService({'name': 'Wifi', 'description': 'Gratis'}, 0).category, 'Servicios');
    });
  });

  group('pollFromJson', () {
    test('mapea encuesta con opciones y mi_voto', () {
      final p = pollFromJson({
        'id': 5,
        'pregunta': '¿Mejor charla?',
        'program_id': 10,
        'activa': true,
        'opciones': [
          {'indice': 0, 'texto': 'A', 'votos': 3},
          {'indice': 1, 'texto': 'B', 'votos': 7},
        ],
        'mi_voto': 1,
      });
      expect(p.id, '5');
      expect(p.sessionId, '10'); // program_id → sessionId
      expect(p.question, '¿Mejor charla?');
      expect(p.options.length, 2);
      expect(p.options[0].id, '0'); // indice → id
      expect(p.options[1].seedVotes, 7);
      expect(p.myVoteIndex, 1);
    });

    test('program_id null → sessionId vacío; sin mi_voto', () {
      final p = pollFromJson({'id': 1, 'pregunta': 'X', 'program_id': null, 'opciones': []});
      expect(p.sessionId, '');
      expect(p.myVoteIndex, isNull);
    });
  });
}
