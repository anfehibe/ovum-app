import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/data/models/info_item.dart';
import 'package:ovum/data/models/networking_catalog.dart';
import 'package:ovum/data/models/networking_meeting.dart';
import 'package:ovum/data/models/session.dart';
import 'package:ovum/data/models/sponsor.dart';
import 'package:ovum/data/repositories/mappers/attendee_mapper.dart';
import 'package:ovum/data/repositories/mappers/content_mapper.dart';
import 'package:ovum/data/repositories/mappers/hotel_mapper.dart';
import 'package:ovum/data/repositories/mappers/networking_mapper.dart';
import 'package:ovum/data/repositories/mappers/poll_mapper.dart';
import 'package:ovum/data/repositories/mappers/question_mapper.dart';
import 'package:ovum/data/repositories/mappers/session_mapper.dart';
import 'package:ovum/data/repositories/mappers/speaker_mapper.dart';
import 'package:ovum/data/repositories/mappers/splash_mapper.dart';
import 'package:ovum/data/repositories/mappers/sponsor_mapper.dart';
import 'package:ovum/data/repositories/mappers/venue_mapper.dart';
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

    // El API no tiene campo para separar el programa científico de la agenda
    // general: reutiliza el agrupamiento de `data[]` (sedes) para eso.
    test('una sede con dirección/coords es la agenda general', () {
      expect(sessionsFromAgendaJson(venues).first.agendaGroup, 'Agenda general');
    });

    test('una sede sin dirección, coords ni planos se etiqueta con su nombre', () {
      final logico = [
        {
          'id': 4,
          'nombre': 'Programa Científico',
          'direccion': null,
          'lat': null,
          'lng': null,
          'planos': [],
          'sesiones': [
            {
              'id': 11,
              'titulo': 'Influenza Aviar',
              'sala': 'Plenaria',
              'inicio': '2026-11-11T09:00:00-05:00',
              'fin': '2026-11-11T10:00:00-05:00',
            },
          ],
        },
      ];
      expect(sessionsFromAgendaJson(logico).first.agendaGroup, 'Programa Científico');
    });

    test('una sede con planos pero sin dirección sigue siendo agenda general', () {
      final conPlano = [
        {
          'nombre': 'Recinto',
          'planos': [
            {'id': 1, 'titulo': 'Mapa', 'imagen': 'https://x/m.jpg'},
          ],
          'sesiones': [
            {
              'id': 12,
              'titulo': 'Charla',
              'inicio': '2026-11-11T11:00:00-05:00',
              'fin': '2026-11-11T12:00:00-05:00',
            },
          ],
        },
      ];
      expect(sessionsFromAgendaJson(conPlano).first.agendaGroup, 'Agenda general');
    });

    test('una sede sin nombre ni datos de sede deja el grupo vacío', () {
      final anonima = [
        {
          'sesiones': [
            {
              'id': 13,
              'titulo': 'Charla',
              'inicio': '2026-11-11T11:00:00-05:00',
              'fin': '2026-11-11T12:00:00-05:00',
            },
          ],
        },
      ];
      expect(sessionsFromAgendaJson(anonima).first.agendaGroup, '');
    });
  });

  group('agendaGroupsOf', () {
    Session session(String group, {bool otherActivity = false}) => Session(
          id: 'x',
          title: 't',
          description: '',
          shortDescription: '',
          room: '',
          track: 'General',
          startDate: DateTime(2026, 11, 11),
          endDate: DateTime(2026, 11, 11, 1),
          agendaGroup: group,
          isOtherActivity: otherActivity,
        );

    test('deduplica y preserva el orden de aparición de data[]', () {
      final groups = agendaGroupsOf([
        session('Agenda general'),
        session('Programa Científico'),
        session('Agenda general'),
      ]);
      expect(groups, ['Agenda general', 'Programa Científico']);
    });

    test('ignora otras actividades y sesiones sin grupo', () {
      final groups = agendaGroupsOf([
        session(''),
        session('Cóctel', otherActivity: true),
        session('Programa Científico'),
      ]);
      expect(groups, ['Programa Científico']);
    });

    test('sin agenda no hay grupos', () {
      expect(agendaGroupsOf(const []), isEmpty);
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
      expect(s.tier.label, 'Oro');
      expect(s.description, 'Líder en avicultura');
      expect(s.logoUrl, 'https://x/acme.png');
      expect(s.web, 'https://acme.com');
    });

    test('Platino es conocido y va por encima de Oro; logo relativo → null', () {
      final s = sponsorFromJson(
          {'id': 4, 'nombre': 'X', 'nivel': 'Platino', 'logo': '/img/no_pic.jpg'});
      expect(s.tier, SponsorTier.platino);
      expect(s.tier.label, 'Platino');
      expect(s.tier.order, lessThan(SponsorTier.oro.order));
      expect(s.logoUrl, isNull);
    });

    test('nivel nuevo conserva su etiqueta y va al final (no se disfraza de bronce)', () {
      final s = sponsorFromJson({'id': 5, 'nombre': 'Y', 'nivel': 'Media Partner'});
      expect(s.tier.isKnown, isFalse);
      expect(s.tier.label, 'Media Partner'); // casing intacto
      expect(s.tier.order, greaterThan(SponsorTier.bronce.order));
      expect(s.tier, isNot(SponsorTier.bronce)); // guardia de la regresión
    });

    test('la clave del mock y la etiqueta del API son el mismo nivel', () {
      expect(sponsorFromJson({'id': 6, 'nombre': 'A', 'nivel': 'diamante'}).tier,
          SponsorTier.diamante);
      expect(sponsorFromJson({'id': 7, 'nombre': 'B', 'nivel': 'Diamante'}).tier,
          SponsorTier.diamante);
    });

    test('nivel nulo o vacío → otros, nunca bronce', () {
      for (final nivel in [null, '', '   ']) {
        final s = sponsorFromJson({'id': 8, 'nombre': 'Z', 'nivel': nivel});
        expect(s.tier, SponsorTier.otros);
        expect(s.tier, isNot(SponsorTier.bronce));
      }
    });
  });

  group('SponsorTier', () {
    Sponsor sponsorWith(String nivel, String id) =>
        sponsorFromJson({'id': id, 'nombre': 'S$id', 'nivel': nivel});

    test('agrupa por valor: el mismo nivel con distinto casing es una sola clave', () {
      final a = SponsorTier.fromLabel('Media Partner');
      final b = SponsorTier.fromLabel('media partner');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // Contrato que protege el Map<SponsorTier, List<Sponsor>> de sponsors_screen:
      // sin igualdad por valor cada patrocinador formaría su propia sección.
      final byTier = <SponsorTier, List<Sponsor>>{};
      for (final s in [
        sponsorWith('Media Partner', '1'),
        sponsorWith('media partner', '2'),
        sponsorWith('MEDIA PARTNER', '3'),
      ]) {
        byTier.putIfAbsent(s.tier, () => []).add(s);
      }
      expect(byTier.length, 1);
      expect(byTier.values.single.length, 3);
    });

    test('ignora acentos al agrupar pero los conserva en la etiqueta', () {
      final conAcento = SponsorTier.fromLabel('Línea Aérea Oficial');
      expect(conAcento, SponsorTier.fromLabel('Linea Aerea Oficial'));
      expect(conAcento.label, 'Línea Aérea Oficial');
    });

    test('ordena los conocidos por rango y deja los nuevos al final', () {
      final tiers = [
        SponsorTier.fromLabel('Media Partner'),
        SponsorTier.bronce,
        SponsorTier.diamante,
        SponsorTier.platino,
      ]..sort();
      expect(tiers.map((t) => t.label).toList(),
          ['Diamante', 'Platino', 'Bronce', 'Media Partner']);
    });

    test('topTierSponsors toma los dos niveles conocidos más altos presentes', () {
      final top = topTierSponsors([
        sponsorWith('Diamante', '1'),
        sponsorWith('Platino', '2'),
        sponsorWith('Oro', '3'),
        sponsorWith('Media Partner', '4'),
      ]);
      expect(top.map((s) => s.id).toList(), ['1', '2']);
    });

    test('topTierSponsors sube de nivel cuando no hay Diamante', () {
      final top = topTierSponsors([
        sponsorWith('Oro', '1'),
        sponsorWith('Plata', '2'),
        sponsorWith('Bronce', '3'),
      ]);
      expect(top.map((s) => s.id).toList(), ['1', '2']);
    });

    test('topTierSponsors no deja el home vacío si solo hay niveles nuevos', () {
      expect(topTierSponsors([sponsorWith('Media Partner', '1')]), isNotEmpty);
      expect(topTierSponsors(const []), isEmpty);
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

  group('splashFromJson', () {
    test('mapea orden, imagen (absoluta) y link', () {
      final s = splashFromJson({
        'orden': 1,
        'imagen': 'https://trivvo.events/storage/agenda/splashes/s.jpg',
        'link': null,
      });
      expect(s.order, 1);
      expect(s.imageUrl, 'https://trivvo.events/storage/agenda/splashes/s.jpg');
      expect(s.link, isNull);
    });

    test('imagen relativa → null', () {
      expect(splashFromJson({'orden': 2, 'imagen': '/img/no_pic.jpg'}).imageUrl, isNull);
    });
  });

  group('hotelFromJson', () {
    test('mapea contacto/reservar/agotado y habitaciones (precio "desde")', () {
      final h = hotelFromJson({
        'id': 7,
        'nombre': 'Real InterContinental',
        'direccion': 'Av. Las Américas 9-08',
        'telefono': '+502 2413-4444',
        'email': 'reservas@hotel.com',
        'contacto': 'Esperanza García',
        'web': 'https://hotel.com',
        'reservar': 'https://hotel.com/reservar',
        'agotado': false,
        'descripcion': 'Tarifa especial del congreso',
        'imagen': 'https://trivvo.events/storage/hotels/h.jpg',
        'habitaciones': [
          {'id': 1, 'nombre': 'Doble', 'codigo': 'DBL', 'precio': '150.00', 'capacidad': 2},
          {'id': 2, 'nombre': 'Sencilla', 'codigo': 'SGL', 'precio': '120.00', 'capacidad': 1},
        ],
      });
      expect(h.id, '7');
      expect(h.name, 'Real InterContinental');
      expect(h.contact, 'Esperanza García');
      expect(h.bookingUrl, 'https://hotel.com/reservar');
      expect(h.soldOut, isFalse);
      expect(h.imageUrl, 'https://trivvo.events/storage/hotels/h.jpg');
      expect(h.rooms.length, 2);
      expect(h.priceFrom, '120.00'); // la tarifa más baja
    });

    test('agotado=true; reservar/imagen vacíos → null; sin habitaciones', () {
      final h = hotelFromJson({
        'id': 8,
        'nombre': 'Courtyard by Marriott',
        'direccion': 'Zona 10',
        'telefono': '+502 2225-2500',
        'reservar': '',
        'imagen': '/img/no_pic.jpg',
        'agotado': true,
        'habitaciones': [],
      });
      expect(h.soldOut, isTrue);
      expect(h.bookingUrl, isNull);
      expect(h.imageUrl, isNull); // ruta relativa placeholder
      expect(h.priceFrom, isNull);
      expect(h.rooms, isEmpty);
    });
  });

  group('venuesFromAgendaJson', () {
    test('extrae sedes con planos; coords → isPrimary; plano sin imagen se descarta', () {
      final venues = venuesFromAgendaJson([
        {
          'id': 1,
          'nombre': 'Host Venue Parque de La Industria',
          'direccion': '6a Calle, Cdad. de Guatemala',
          // El backend manda las coords como String, incluso con coma final.
          'lat': '14.609184161164723,', 'lng': '-90.52377176014456',
          'planos': [
            {'id': 1, 'titulo': 'Mapa General', 'imagen': 'https://trivvo.events/storage/agenda/planos/p.jpg'},
            {'id': 2, 'titulo': 'Sin imagen', 'imagen': '/img/no_pic.jpg'},
          ],
          'sesiones': [],
        },
        {
          'id': 4, 'nombre': 'Programa Científico', 'direccion': '',
          'lat': null, 'lng': null, 'planos': [], 'sesiones': [],
        },
      ]);
      expect(venues.length, 2);
      final host = venues.first;
      expect(host.id, '1');
      expect(host.lat, closeTo(14.6091, 0.001)); // string "14.60…," → double
      expect(host.isPrimary, isTrue); // tiene coordenadas
      expect(host.plans.length, 1); // el plano con ruta relativa se descarta
      expect(host.plans.first.title, 'Mapa General');
      final program = venues[1];
      expect(program.isPrimary, isFalse);
      expect(program.plans, isEmpty);
    });
  });

  group('questionsFromProgramJson', () {
    test('extrae preguntas aprobadas; respuesta vacía → answer null', () {
      final qs = questionsFromProgramJson({
        'data': {
          'id': 10,
          'titulo': 'Influenza Aviar',
          'preguntas': [
            {'id': 1, 'pregunta': '¿Vigencia del plan?', 'respuesta': 'Doce meses.'},
            {'id': 2, 'pregunta': 'Sin responder aún', 'respuesta': ''},
            {'id': 3, 'pregunta': '   ', 'respuesta': 'X'}, // pregunta vacía → se descarta
          ],
        },
      }, '10');
      expect(qs.length, 2);
      expect(qs.first.sessionId, '10');
      expect(qs.first.isAnswered, isTrue);
      expect(qs.first.answer, 'Doce meses.');
      expect(qs[1].isAnswered, isFalse); // respuesta vacía
    });

    test('sin preguntas / shape inesperado → lista vacía', () {
      expect(questionsFromProgramJson({'data': {'preguntas': null}}, '10'), isEmpty);
      expect(questionsFromProgramJson(const [], '10'), isEmpty);
    });
  });

  group('networkingCardFromJson', () {
    test('mapea el shape completo de la ficha', () {
      final card = networkingCardFromJson({
        'id': 12,
        'nombre': 'Ana',
        'apellido': 'López',
        'foto': 'https://s3/ana.jpg',
        'empresa': 'ACME',
        'cargo': 'Directora',
        'sector': ['Nutrición y alimento balanceado', 'Genética'],
        'intereses': ['Bioseguridad'],
        'bio': 'Veterinaria',
        'linkedin': 'https://linkedin.com/in/ana',
        'pais': 'Guatemala',
        'favorito': true,
      });
      expect(card.id, '12'); // int → String
      expect(card.name, 'Ana López');
      expect(card.subtitle, 'Directora · ACME');
      expect(card.photoUrl, 'https://s3/ana.jpg');
      expect(card.sectors, ['Nutrición y alimento balanceado', 'Genética']);
      expect(card.interests, ['Bioseguridad']);
      expect(card.country, 'Guatemala');
      expect(card.isFavorite, isTrue);
    });

    test('favorito ausente → false', () {
      expect(networkingCardFromJson({'id': 1, 'nombre': 'X'}).isFavorite, isFalse);
    });

    test('descarta el placeholder de foto, relativo o absoluto', () {
      expect(networkingCardFromJson({'id': 1, 'foto': '/img/usuario.jpg'}).photoUrl, isNull);
      // Networking sirve el placeholder como URL absoluta: sin filtrarlo, todas
      // las fichas mostrarían el mismo avatar gris en vez de las iniciales.
      expect(
        networkingCardFromJson(
            {'id': 1, 'foto': 'https://trivvo.events/storage/img/usuario.jpg'}).photoUrl,
        isNull,
      );
      expect(
        networkingCardFromJson({'id': 1, 'foto': 'https://s3/fotos/ana.jpg'}).photoUrl,
        'https://s3/fotos/ana.jpg',
      );
    });

    test('campos nulos → cadenas vacías, sin crash', () {
      final card = networkingCardFromJson({
        'id': 2,
        'nombre': 'Solo',
        'apellido': null,
        'empresa': null,
        'cargo': null,
        'bio': null,
        'pais': null,
        'linkedin': null,
      });
      expect(card.name, 'Solo');
      expect(card.subtitle, '');
      expect(card.bio, '');
      expect(card.linkedin, isNull);
      expect(card.sectors, isEmpty);
    });

    test('buscando/soluciones/regiones solo vienen en el detalle', () {
      final lista = networkingCardFromJson({'id': 3, 'nombre': 'A'});
      expect(lista.seeking, isEmpty);
      final detalle = networkingCardFromJson({
        'id': 3,
        'nombre': 'A',
        'buscando': ['proveedores'],
        'soluciones': ['sanidad', 'nutricion'],
        'regiones': ['centroamerica'],
      });
      expect(detalle.seeking, ['proveedores']);
      expect(detalle.solutions, ['sanidad', 'nutricion']);
      expect(detalle.regions, ['centroamerica']);
    });
  });

  group('directoryPageFromJson', () {
    test('lee data + meta de paginación', () {
      final page = directoryPageFromJson({
        'data': [
          {'id': 1, 'nombre': 'A'},
          {'id': 2, 'nombre': 'B'},
        ],
        'meta': {'page': 2, 'per': 25, 'total': 57, 'last_page': 3},
      });
      expect(page.items.length, 2);
      expect(page.page, 2);
      expect(page.lastPage, 3);
      expect(page.total, 57);
    });

    test('sin meta → página 1 de 1 y total = items', () {
      final page = directoryPageFromJson({
        'data': [
          {'id': 1, 'nombre': 'A'},
        ],
      });
      expect(page.page, 1);
      expect(page.lastPage, 1);
      expect(page.total, 1);
    });
  });

  group('networkingCatalogFromJson', () {
    test('sectores/intereses (sin clave) usan la etiqueta es como valor', () {
      final cat = networkingCatalogFromJson({
        'sectores': [
          {'es': 'Producción de pollo de engorde', 'en': 'Broiler production'},
        ],
        'intereses': [
          {'es': 'Bioseguridad', 'en': 'Biosecurity'},
        ],
      });
      expect(cat.sectors.single.value, 'Producción de pollo de engorde');
      expect(cat.sectors.single.es, 'Producción de pollo de engorde');
      expect(cat.interests.single.value, 'Bioseguridad');
    });

    test('buscando/soluciones/regiones usan clave y conservan el ícono', () {
      final cat = networkingCatalogFromJson({
        'soluciones': [
          {'clave': 'genetica', 'es': 'Genética', 'en': 'Genetics', 'icono': 'fa-dna'},
        ],
      });
      final opt = cat.solutions.single;
      expect(opt.value, 'genetica'); // la clave, no la etiqueta
      expect(opt.es, 'Genética');
      expect(opt.icon, 'fa-dna');
    });

    test('lee topes; sin topes cae a 3 / 7', () {
      final conTopes = networkingCatalogFromJson({
        'topes': {'sectores': 2, 'intereses': 5},
      });
      expect(conTopes.maxSectors, 2);
      expect(conTopes.maxInterests, 5);
      final sinTopes = networkingCatalogFromJson({});
      expect(sinTopes.maxSectors, 3);
      expect(sinTopes.maxInterests, 7);
    });
  });

  group('networkingProfileFromJson', () {
    test('extrae la ficha y las cinco listas de selección', () {
      final p = networkingProfileFromJson({
        'activo': true,
        'sector': ['Genética'],
        'intereses': ['Bioseguridad', 'Nutrición'],
        'buscando': ['proveedores'],
        'soluciones': ['sanidad'],
        'regiones': ['centroamerica'],
        'perfil': {'id': 7, 'nombre': 'Yo', 'apellido': 'Mismo', 'favorito': false},
      });
      expect(p.card.name, 'Yo Mismo');
      expect(p.sectors, ['Genética']);
      expect(p.interests.length, 2);
      expect(p.seeking, ['proveedores']);
      expect(p.isEmpty, isFalse);
    });

    test('perfil vacío → isEmpty y ficha sin favorito', () {
      final p = networkingProfileFromJson({'activo': true, 'perfil': {'id': 7}});
      expect(p.isEmpty, isTrue);
      expect(p.card.isFavorite, isFalse);
    });
  });

  group('networkingProfileBody', () {
    test('recorta a 3 sectores y 7 intereses como el servidor', () {
      final body = networkingProfileBody(
        sectors: ['a', 'b', 'c', 'd', 'e'],
        interests: List.generate(10, (i) => 'i$i'),
        seeking: const [],
        solutions: const [],
        regions: const [],
      );
      expect((body['sector'] as List).length, 3);
      expect((body['intereses'] as List).length, 7);
      expect(body['buscando'], isEmpty); // se envían vacías, no se omiten
    });

    test('respeta los topes que declare el catálogo', () {
      final body = networkingProfileBody(
        sectors: ['a', 'b', 'c'],
        interests: const [],
        seeking: const [],
        solutions: const [],
        regions: const [],
        catalog: const NetworkingCatalog(maxSectors: 1, maxInterests: 2),
      );
      expect((body['sector'] as List).length, 1);
    });
  });

  group('networkingMeetingFromJson', () {
    test('mapea soy/estado/contraparte', () {
      final m = networkingMeetingFromJson({
        'id': 44,
        'estatus': 1,
        'estado': 'Pendiente',
        'soy': 'destinatario',
        'con': {'id': 9, 'nombre': 'Luis', 'apellido': 'Paz'},
        'mensaje': '¿Hablamos de nutrición?',
        'respuesta': null,
        'fecha': '2026-11-11',
        'hora_inicio': '10:00',
        'hora_fin': '10:30',
      });
      expect(m.id, '44');
      expect(m.state, MeetingState.pending);
      expect(m.stateLabel, 'Pendiente'); // se muestra la copy del servidor
      expect(m.isIncoming, isTrue);
      expect(m.counterpart.name, 'Luis Paz');
      expect(m.date, DateTime(2026, 11, 11));
      expect(m.startTime, '10:00');
      expect(m.hasSchedule, isTrue);
    });

    test('soy remitente → isIncoming false', () {
      final m = networkingMeetingFromJson({'id': 1, 'estatus': 2, 'soy': 'remitente'});
      expect(m.isIncoming, isFalse);
      expect(m.state, MeetingState.confirmed);
    });

    test('mapea los seis estatus y uno desconocido no lanza', () {
      const esperados = [
        MeetingState.deleted,
        MeetingState.pending,
        MeetingState.confirmed,
        MeetingState.declined,
        MeetingState.rescheduled,
        MeetingState.expired,
      ];
      for (var code = 0; code <= 5; code++) {
        expect(MeetingState.fromCode(code), esperados[code]);
      }
      expect(networkingMeetingFromJson({'id': 1, 'estatus': 9}).state, MeetingState.unknown);
      expect(networkingMeetingFromJson({'id': 1, 'estatus': null}).state, MeetingState.unknown);
    });

    test('fecha/horas nulas o vacías → null, sin parsear cadenas vacías', () {
      final m = networkingMeetingFromJson({
        'id': 2,
        'estatus': 1,
        'fecha': null,
        'hora_inicio': '',
        'hora_fin': null,
      });
      expect(m.date, isNull);
      expect(m.startTime, isNull);
      expect(m.endTime, isNull);
      expect(m.hasSchedule, isFalse);
    });

    test('el listado de hoy no trae lugar/mesa → placeLabel null', () {
      final m = networkingMeetingFromJson({'id': 3, 'estatus': 2});
      expect(m.place, isNull);
      expect(m.table, 0);
      expect(m.placeLabel, isNull);
    });

    test('con lugar/mesa se mapean (compatibilidad futura del listado)', () {
      final conMesa = networkingMeetingFromJson(
          {'id': 4, 'estatus': 2, 'lugar': 'Salón A', 'mesa': 3});
      expect(conMesa.placeLabel, 'Mesa 3 · Salón A');
      // Espacio abierto: hay sala pero no mesa numerada.
      final abierto = networkingMeetingFromJson(
          {'id': 5, 'estatus': 2, 'lugar': 'Salón A', 'mesa': 0});
      expect(abierto.placeLabel, 'Salón A');
    });
  });

  group('meetingOutcomeFromJson', () {
    test('aceptar con mesa asignada', () {
      final o = meetingOutcomeFromJson(
          {'id': 9, 'estatus': 2, 'estado': 'Confirmada', 'lugar': 'Salón A', 'mesa': 3});
      expect(o.id, '9');
      expect(o.state, MeetingState.confirmed);
      expect(o.stateLabel, 'Confirmada');
      expect(outcomePlaceLabel(o), 'Mesa 3 · Salón A');
    });

    test('rechazar no trae lugar ni mesa', () {
      final o = meetingOutcomeFromJson({'id': 9, 'estatus': 3, 'estado': 'Rechazada'});
      expect(o.state, MeetingState.declined);
      expect(o.place, isNull);
      expect(o.table, 0);
      expect(outcomePlaceLabel(o), isNull);
    });

    test('aceptar sin mesa libre → mesa pendiente', () {
      final o = meetingOutcomeFromJson(
          {'id': 9, 'estatus': 2, 'estado': 'Confirmada', 'lugar': null, 'mesa': 0});
      expect(outcomePlaceLabel(o), isNull); // la copy "por asignar" vive en la UI
    });
  });

  group('networkingMessageFromJson', () {
    test('mapea {id, mio, texto, fecha} y convierte la fecha a local', () {
      final m = networkingMessageFromJson({
        'id': 41,
        'mio': true,
        'texto': '¡Listo!',
        'fecha': '2026-11-11T14:25:00-05:00',
      });
      expect(m.id, '41');
      expect(m.isMine, isTrue);
      expect(m.text, '¡Listo!');
      expect(m.pending, isFalse);
      // A diferencia de la agenda (wallClock), aquí SÍ se pasa a local.
      expect(m.sentAt!.isUtc, isFalse);
      expect(
        m.sentAt!.toUtc(),
        DateTime.utc(2026, 11, 11, 19, 25), // 14:25 -05:00
      );
    });

    test('mio ausente → false; fecha nula o vacía → null', () {
      expect(networkingMessageFromJson({'id': 1, 'texto': 'x'}).isMine, isFalse);
      expect(networkingMessageFromJson({'id': 1, 'fecha': null}).sentAt, isNull);
      expect(networkingMessageFromJson({'id': 1, 'fecha': ''}).sentAt, isNull);
    });
  });

  group('conversationsFromJson', () {
    test('mapea con/ultimo/total y conserva el orden del servidor', () {
      final list = conversationsFromJson({
        'data': [
          {
            'con': {'id': 7, 'nombre': 'Luis', 'apellido': 'Paz', 'empresa': 'ACME'},
            'ultimo': {'texto': 'Nos vemos', 'mio': false, 'fecha': '2026-11-11T14:22:00-05:00'},
            'total': 5,
          },
          {
            'con': {'id': 8, 'nombre': 'Ana', 'apellido': 'Ríos'},
            'ultimo': {'texto': 'Ok', 'mio': true, 'fecha': null},
            'total': 2,
          },
        ],
      });
      expect(list.length, 2);
      expect(list.first.counterpart.name, 'Luis Paz');
      expect(list.first.lastText, 'Nos vemos');
      expect(list.first.lastIsMine, isFalse);
      expect(list.first.total, 5);
      expect(list.first.lastAt!.isUtc, isFalse);
      // El servidor ya ordena de más reciente a más antigua: no se reordena.
      expect(list[1].counterpart.name, 'Ana Ríos');
      expect(list[1].lastIsMine, isTrue);
      expect(list[1].lastAt, isNull);
    });

    test('ultimo ausente, con ausente y shape inesperado no lanzan', () {
      final sinUltimo = conversationsFromJson({
        'data': [
          {'con': {'id': 7, 'nombre': 'Luis'}},
        ],
      });
      expect(sinUltimo.single.lastText, '');
      expect(sinUltimo.single.total, 0);
      expect(conversationsFromJson({'data': [{'total': 1}]}).single.counterpart.id, '');
      expect(conversationsFromJson({'data': null}), isEmpty);
      expect(conversationsFromJson(const []), isEmpty);
    });
  });

  group('messageThreadFromJson', () {
    test('mapea con + mensajes en orden cronológico', () {
      final t = messageThreadFromJson({
        'con': {'id': 7, 'nombre': 'Luis', 'apellido': 'Paz'},
        'mensajes': [
          {'id': 40, 'mio': true, 'texto': 'Hola', 'fecha': '2026-11-11T14:20:00-05:00'},
          {'id': 41, 'mio': false, 'texto': 'Qué tal', 'fecha': '2026-11-11T14:21:00-05:00'},
        ],
      });
      expect(t.counterpart.name, 'Luis Paz');
      expect(t.messages.map((m) => m.id).toList(), ['40', '41']);
      expect(t.messages.first.isMine, isTrue);
      expect(t.messages.last.isMine, isFalse);
    });

    test('sin mensajes o sin con no lanza', () {
      final sinMensajes = messageThreadFromJson({'con': {'id': 7, 'nombre': 'Luis'}});
      expect(sinMensajes.messages, isEmpty);
      expect(sinMensajes.counterpart.name, 'Luis');
      expect(messageThreadFromJson(const {}).counterpart.id, '');
    });
  });
}
