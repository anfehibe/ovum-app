import '../../../core/utils/url_ext.dart';
import '../../models/networking_card.dart';
import '../../models/networking_catalog.dart';
import '../../models/networking_meeting.dart';
import '../../models/networking_message.dart';
import '../../models/networking_profile.dart';

/// Mapea las respuestas de `/events/{id}/networking/*` del API TRIVVO.
///
/// Todas son funciones puras y defensivas: el shape real se documenta en cada una
/// y los campos ausentes caen a vacío en vez de lanzar.

// ── Ficha de asistente ──────────────────────────────────────────────────────

/// Shape real: `{id, nombre, apellido, foto, empresa, cargo, sector[],
/// intereses[], bio, linkedin, pais, favorito}` (+ `buscando/soluciones/regiones`
/// solo en el detalle). Aquí `foto` llega **absoluta** (S3), incluido el
/// placeholder `.../img/usuario.jpg`, por eso se usa [personPhotoOrNull] y no
/// [absoluteUrlOrNull]: si no, todas las fichas mostrarían el mismo avatar gris.
NetworkingCard networkingCardFromJson(Map<String, dynamic> j) {
  return NetworkingCard(
    id: '${j['id']}',
    firstName: _text(j['nombre']),
    lastName: _text(j['apellido']),
    photoUrl: personPhotoOrNull(j['foto'] as String?),
    company: _text(j['empresa']),
    position: _text(j['cargo']),
    sectors: _strings(j['sector']),
    interests: _strings(j['intereses']),
    bio: _text(j['bio']),
    linkedin: _textOrNull(j['linkedin']),
    country: _text(j['pais']),
    isFavorite: j['favorito'] == true,
    seeking: _strings(j['buscando']),
    solutions: _strings(j['soluciones']),
    regions: _strings(j['regiones']),
  );
}

/// `{data:[card], meta:{page, per, total, last_page}}`. Tolera `meta` ausente
/// (página 1 de 1) para no romper si el backend simplifica la respuesta.
DirectoryPage directoryPageFromJson(dynamic response) {
  final root = response is Map ? response : const {};
  final rawItems = root['data'];
  final items = <NetworkingCard>[
    if (rawItems is List)
      for (final e in rawItems)
        if (e is Map) networkingCardFromJson(e.cast<String, dynamic>()),
  ];
  final meta = root['meta'];
  int metaInt(String key, int fallback) {
    final v = meta is Map ? meta[key] : null;
    return v is num ? v.toInt() : fallback;
  }

  return (
    items: items,
    page: metaInt('page', 1),
    lastPage: metaInt('last_page', 1),
    total: metaInt('total', items.length),
  );
}

// ── Catálogo ────────────────────────────────────────────────────────────────

/// `{sectores[], intereses[], buscando[], soluciones[], regiones[], topes{}}`.
///
/// OJO: `sectores`/`intereses` llegan como `{es, en}` **sin `clave`** y lo que el
/// backend almacena es la etiqueta en español; los otros tres traen `{clave, es,
/// en, icono}`. [_options] unifica ambos en [CatalogOption].
NetworkingCatalog networkingCatalogFromJson(Map<String, dynamic> data) {
  final topes = data['topes'];
  int cap(String key, int fallback) {
    final v = topes is Map ? topes[key] : null;
    return v is num ? v.toInt() : fallback;
  }

  return NetworkingCatalog(
    sectors: _options(data['sectores']),
    interests: _options(data['intereses']),
    seeking: _options(data['buscando']),
    solutions: _options(data['soluciones']),
    regions: _options(data['regiones']),
    maxSectors: cap('sectores', 3),
    maxInterests: cap('intereses', 7),
  );
}

// ── Perfil propio ───────────────────────────────────────────────────────────

/// `{activo, sector[], intereses[], buscando[], soluciones[], regiones[], perfil{}}`.
/// `activo` se ignora a propósito (siempre `true` en un 200; el 403 es la señal).
NetworkingProfile networkingProfileFromJson(Map<String, dynamic> data) {
  final perfil = data['perfil'];
  return NetworkingProfile(
    card: perfil is Map
        ? networkingCardFromJson(perfil.cast<String, dynamic>())
        : const NetworkingCard(id: ''),
    sectors: _strings(data['sector']),
    interests: _strings(data['intereses']),
    seeking: _strings(data['buscando']),
    solutions: _strings(data['soluciones']),
    regions: _strings(data['regiones']),
  );
}

/// Cuerpo del `PUT /networking/me`, aplicando **los mismos topes que el servidor**
/// (3 sectores / 7 intereses). El backend trunca en silencio; recortar aquí evita
/// que la UI muestre selecciones que nunca se guardaron.
Map<String, dynamic> networkingProfileBody({
  required List<String> sectors,
  required List<String> interests,
  required List<String> seeking,
  required List<String> solutions,
  required List<String> regions,
  NetworkingCatalog? catalog,
}) {
  return {
    'sector': sectors.take(catalog?.maxSectors ?? 3).toList(),
    'intereses': interests.take(catalog?.maxInterests ?? 7).toList(),
    'buscando': seeking,
    'soluciones': solutions,
    'regiones': regions,
  };
}

// ── Reuniones ───────────────────────────────────────────────────────────────

/// `{id, estatus, estado, soy, con{card}, mensaje, respuesta, fecha, hora_inicio,
/// hora_fin}`. Un `estatus` no previsto cae a [MeetingState.unknown] sin lanzar.
NetworkingMeeting networkingMeetingFromJson(Map<String, dynamic> j) {
  final con = j['con'];
  return NetworkingMeeting(
    id: '${j['id']}',
    state: MeetingState.fromCode(j['estatus']),
    stateLabel: _text(j['estado']),
    isIncoming: _text(j['soy']).toLowerCase() == 'destinatario',
    counterpart: con is Map
        ? networkingCardFromJson(con.cast<String, dynamic>())
        : const NetworkingCard(id: ''),
    message: _text(j['mensaje']),
    reply: _text(j['respuesta']),
    date: DateTime.tryParse(_text(j['fecha'])),
    startTime: _textOrNull(j['hora_inicio']),
    endTime: _textOrNull(j['hora_fin']),
    // Hoy el listado no los manda; se leen para cuando el backend los agregue.
    place: _textOrNull(j['lugar']),
    table: _int(j['mesa']),
  );
}

/// `{id, estatus, estado, lugar?, mesa?}` de `POST .../meetings/{id}/respond`.
/// Al rechazar no vienen `lugar`/`mesa`.
MeetingOutcome meetingOutcomeFromJson(Map<String, dynamic> j) => (
  id: '${j['id']}',
  state: MeetingState.fromCode(j['estatus']),
  stateLabel: _text(j['estado']),
  place: _textOrNull(j['lugar']),
  table: _int(j['mesa']),
);

// ── Mensajes ────────────────────────────────────────────────────────────────

/// `{id, mio, texto, fecha}`. La fecha se pasa a **local** a propósito: el backend
/// corre en `America/Bogota` y aquí sí queremos la hora del dispositivo (a
/// diferencia de la agenda, que usa `wallClock` porque sus offsets no son fiables).
NetworkingMessage networkingMessageFromJson(Map<String, dynamic> j) =>
    NetworkingMessage(
      id: '${j['id']}',
      isMine: j['mio'] == true,
      text: _text(j['texto']),
      sentAt: DateTime.tryParse(_text(j['fecha']))?.toLocal(),
    );

/// `{data:[{con, ultimo:{texto,mio,fecha}, total}]}` — el servidor ya las manda
/// de la más reciente a la más antigua; **no se reordenan**.
List<ConversationSummary> conversationsFromJson(dynamic response) {
  final raw = response is Map ? response['data'] : response;
  if (raw is! List) return const [];
  final out = <ConversationSummary>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final j = e.cast<String, dynamic>();
    final con = j['con'];
    final ultimo = j['ultimo'];
    final last = ultimo is Map ? ultimo.cast<String, dynamic>() : const {};
    out.add(ConversationSummary(
      counterpart: con is Map
          ? networkingCardFromJson(con.cast<String, dynamic>())
          : const NetworkingCard(id: ''),
      lastText: _text(last['texto']),
      lastIsMine: last['mio'] == true,
      lastAt: DateTime.tryParse(_text(last['fecha']))?.toLocal(),
      total: _int(j['total']),
    ));
  }
  return out;
}

/// `{con:{…}, mensajes:[…]}` en orden cronológico.
MessageThread messageThreadFromJson(Map<String, dynamic> data) {
  final con = data['con'];
  final raw = data['mensajes'];
  return (
    counterpart: con is Map
        ? networkingCardFromJson(con.cast<String, dynamic>())
        : const NetworkingCard(id: ''),
    messages: <NetworkingMessage>[
      if (raw is List)
        for (final e in raw)
          if (e is Map) networkingMessageFromJson(e.cast<String, dynamic>()),
    ],
  );
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String _text(dynamic v) => v is String ? v.trim() : '';

int _int(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);

String? _textOrNull(dynamic v) {
  final t = _text(v);
  return t.isEmpty ? null : t;
}

List<String> _strings(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e != null && '$e'.trim().isNotEmpty) '$e'.trim(),
  ];
}

List<CatalogOption> _options(dynamic raw) {
  if (raw is! List) return const [];
  final out = <CatalogOption>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final m = e.cast<String, dynamic>();
    final es = _text(m['es']);
    final clave = _text(m['clave']);
    // Sin `clave` (sectores/intereses) el valor canónico es la etiqueta española.
    final value = clave.isNotEmpty ? clave : es;
    if (value.isEmpty) continue;
    out.add(CatalogOption(
      value: value,
      es: es.isEmpty ? value : es,
      en: _text(m['en']),
      icon: _textOrNull(m['icono']),
    ));
  }
  return out;
}
