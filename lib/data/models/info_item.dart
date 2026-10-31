/// Tipo de acción asociada a una tarjeta de información.
enum InfoActionType { none, url, phone, email }

/// Tarjeta de información general (Guatemala, vuelos, visas, contacto…).
class InfoItem {
  final String id;
  final String category;
  final String title;
  final String body;

  /// Clave de ícono (se resuelve a un PhosphorIcon en la UI).
  final String icon;
  final String? actionLabel;
  final String? actionValue;
  final InfoActionType actionType;

  const InfoItem({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    this.icon = 'info',
    this.actionLabel,
    this.actionValue,
    this.actionType = InfoActionType.none,
  });
}
