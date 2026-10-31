/// Habitación / tarifa de un hotel (opcional; el backend puede no traerlas).
class HotelRoom {
  final String id;
  final String name;
  final String? code;
  final String? price; // p. ej. "120.00" (moneda la define el organizador)
  final int? capacity;
  final int? available;
  final String? from; // ISO date de disponibilidad
  final String? to;

  const HotelRoom({
    required this.id,
    required this.name,
    this.code,
    this.price,
    this.capacity,
    this.available,
    this.from,
    this.to,
  });
}

/// Hotel recomendado / oficial para el alojamiento.
class Hotel {
  final String id;
  final String name;
  final String description;
  final String address;
  final String distance;
  final String? priceFrom;
  final String? imageUrl;
  final String? web;
  final String? phone;
  final String? email;

  /// Persona de contacto para reservas (campo `contacto` del API).
  final String? contact;

  /// Enlace del botón "Reservar" (URL http(s) o `mailto:`).
  final String? bookingUrl;

  /// Cupo agotado → mostrar el sello "AGOTADO".
  final bool soldOut;

  /// Habitaciones/tarifas si el backend las provee (hoy suele venir vacío).
  final List<HotelRoom> rooms;

  final bool isOfficial;

  const Hotel({
    required this.id,
    required this.name,
    this.description = '',
    this.address = '',
    this.distance = '',
    this.priceFrom,
    this.imageUrl,
    this.web,
    this.phone,
    this.email,
    this.contact,
    this.bookingUrl,
    this.soldOut = false,
    this.rooms = const [],
    this.isOfficial = false,
  });
}
