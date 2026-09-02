import '../../../core/utils/url_ext.dart';
import '../../models/exhibitor.dart';
import '../../models/info_item.dart';
import '../../models/organizer.dart';

/// Mappers del endpoint `content/{type}` del API TRIVVO.
///
/// OJO: el backend serializa los `$fillable` del modelo y **NO incluye `id`**
/// (Laravel excluye la PK del fillable). Sintetizamos un id estable por índice;
/// si el backend llegara a incluir `id`, se usa ese (forward-compatible).
String _contentId(Map<String, dynamic> j, String prefix, int index) {
  final id = j['id'];
  return id != null ? '$id' : '$prefix-$index';
}

/// `content/organizers` → `{name, position, web, image, order}`.
Organizer organizerFromJson(Map<String, dynamic> j, int index) => Organizer(
  id: _contentId(j, 'org', index),
  name: j['name'] as String? ?? '',
  description: j['position'] as String? ?? '',
  logoUrl: absoluteUrlOrNull(j['image'] as String?),
  web: j['web'] as String?,
);

/// `content/exhibitors` → `{name, stand, level, email, web, image, order}`.
Exhibitor exhibitorFromJson(Map<String, dynamic> j, int index) => Exhibitor(
  id: _contentId(j, 'exh', index),
  name: j['name'] as String? ?? '',
  booth: j['stand'] as String? ?? '',
  category: j['level'] as String? ?? '',
  logoUrl: absoluteUrlOrNull(j['image'] as String?),
  web: j['web'] as String?,
  email: j['email'] as String?,
);

/// `content/interest` → `{title, content, order}`.
InfoItem infoFromInterest(Map<String, dynamic> j, int index) => InfoItem(
  id: _contentId(j, 'info-interest', index),
  category: 'Información general',
  title: j['title'] as String? ?? '',
  body: j['content'] as String? ?? '',
);

/// `content/phones` → `{name, phone, address, order}`.
InfoItem infoFromPhone(Map<String, dynamic> j, int index) {
  final phone = (j['phone'] as String?)?.trim();
  final hasPhone = phone != null && phone.isNotEmpty;
  return InfoItem(
    id: _contentId(j, 'info-phone', index),
    category: 'Contactos',
    title: j['name'] as String? ?? '',
    body: j['address'] as String? ?? '',
    icon: 'phone',
    actionLabel: hasPhone ? phone : null,
    actionValue: hasPhone ? phone : null,
    actionType: hasPhone ? InfoActionType.phone : InfoActionType.none,
  );
}

/// `content/services` → `{name, description, image, order}`.
InfoItem infoFromService(Map<String, dynamic> j, int index) => InfoItem(
  id: _contentId(j, 'info-service', index),
  category: 'Servicios',
  title: j['name'] as String? ?? '',
  body: j['description'] as String? ?? '',
);
