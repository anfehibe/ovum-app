/// Información del único evento de la app: OVUM 2026.
/// (En FELABAN esto era multi-evento; aquí es una constante.)
abstract final class OvumEvent {
  static const String name = 'OVUM 2026';
  static const String edition = 'XXIX Congreso Latinoamericano de Avicultura';
  static const String tagline = 'El mayor encuentro de la industria avícola de Latinoamérica';

  static const String city = 'Ciudad de Guatemala, Guatemala';
  static const String mainVenue = 'Parque de la Industria (COPEREX)';

  /// Días principales del congreso (11–13 de noviembre de 2026).
  static final DateTime startDate = DateTime(2026, 11, 11);
  static final DateTime endDate = DateTime(2026, 11, 13);

  /// Días que muestra la agenda (incluye pre-eventos/registro 9–10 nov).
  static final List<DateTime> agendaDays = [
    DateTime(2026, 11, 11),
    DateTime(2026, 11, 12),
    DateTime(2026, 11, 13),
  ];

  static const String organizers = 'ANAVI Guatemala · ALA';
  static const String contactEmail = 'ovum2026@anaviguatemala.org';
  static const String contactPhone = '+502 2360-3084';
  static const String website = 'https://ovum2026.com';

  static const String officialAirline = 'Copa Airlines';
  static const String airlineDiscountCode = 'B9781';
  static const String officialHotel = 'Hotel Real InterContinental';
}

/// Ventana y rejilla de las reuniones de networking.
///
/// La rejilla de 30 min **no es cosmética**: al aceptar una reunión, el backend
/// busca en `horarios` una fila con la `fecha` y la `hora_inicio` exactas para
/// asignarle mesa (`API/V1/NetworkingController.php:456`), y esas filas van de
/// media en media hora. Una hora fuera de la rejilla se confirma igual, pero
/// **sin mesa y sin avisar**.
///
/// Son horas de **pared**, sin zona horaria: `fecha`/`hora_inicio`/`hora_fin`
/// viajan como strings literales y el backend las guarda tal cual. Por eso aquí
/// no se usa `wallClock` (ver `core/utils/date_ext.dart`) — no hay ningún
/// instante UTC que convertir, a diferencia de la agenda.
abstract final class MeetingHours {
  /// 08:00 — primera hora a la que puede empezar una reunión.
  static const int openingMinute = 8 * 60;

  /// 18:00 — hora de fin más tardía; nada puede terminar después.
  static const int closingMinute = 18 * 60;

  static const int stepMinutes = 30;

  /// El backend solo maneja periodos de 30 y 60 (`periodo => 'in:30,60'`).
  static const List<int> durations = [30, 60];
  static const int defaultDuration = 30;
}
