/// Tipo de acción asociada a una tarjeta de información.
enum InfoActionType { none, url, phone, email }

InfoActionType _actionFromKey(String? key) => switch (key) {
      'url' => InfoActionType.url,
      'phone' => InfoActionType.phone,
      'email' => InfoActionType.email,
      _ => InfoActionType.none,
    };

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

  factory InfoItem.fromJson(Map<String, dynamic> json) {
    return InfoItem(
      id: json['id'] as String,
      category: json['category'] as String? ?? '',
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      icon: json['icon'] as String? ?? 'info',
      actionLabel: json['action_label'] as String?,
      actionValue: json['action_value'] as String?,
      actionType: _actionFromKey(json['action_type'] as String?),
    );
  }
}
