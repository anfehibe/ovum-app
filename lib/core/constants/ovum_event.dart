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
