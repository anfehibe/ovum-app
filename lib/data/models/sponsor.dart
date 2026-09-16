/// Nivel de patrocinio.
///
/// El backend manda `nivel` como **texto libre** de un pivot, no como vocabulario
/// cerrado: en producción ya conviven `Diamante, Platino, Oro, Plata, Bronce,
/// Media Partner, Internet Oficial, Línea Aérea Oficial` (y aparecieron cuatro de
/// esos en una sola semana). Por eso esto no es un `enum`: los niveles conocidos
/// tienen orden y color propios, y **cualquier valor nuevo conserva su etiqueta y
/// se agrupa aparte** en vez de disfrazarse de "Bronce".
///
/// La igualdad es por [key] — es requisito: la pantalla de patrocinadores agrupa
/// con `Map<SponsorTier, List<Sponsor>>` y sin igualdad por valor cada patrocinador
/// formaría su propio grupo.
class SponsorTier implements Comparable<SponsorTier> {
  const SponsorTier._(this.key, this.label, this.order);

  /// Clave normalizada (minúsculas, sin acentos): identidad para agrupar y colorear.
  final String key;

  /// Etiqueta a mostrar; la del backend tal cual cuando el nivel es desconocido.
  final String label;

  /// Prioridad de orden; los desconocidos comparten [unknownOrder] y van al final.
  final int order;

  static const int unknownOrder = 99;

  bool get isKnown => order < unknownOrder;

  /// Texto para encabezados: "Patrocinador Oro", pero "Línea Aérea Oficial" a
  /// secas — esos valores son un rol, no un nivel, y anteponerles "Patrocinador"
  /// queda mal redactado.
  String get badge => isKnown ? 'Patrocinador $label' : label;

  static const diamante = SponsorTier._('diamante', 'Diamante', 0);
  static const platino = SponsorTier._('platino', 'Platino', 1);
  static const oro = SponsorTier._('oro', 'Oro', 2);
  static const plata = SponsorTier._('plata', 'Plata', 3);
  static const bronce = SponsorTier._('bronce', 'Bronce', 4);

  /// Nivel ausente o vacío. Se agrupa aparte; nunca se confunde con Bronce.
  static const otros = SponsorTier._('otros', 'Otros', unknownOrder);

  /// Niveles con orden y color definidos, de mayor a menor.
  static const known = <SponsorTier>[diamante, platino, oro, plata, bronce];

  /// Acepta tanto la clave del mock (`"diamante"`) como la etiqueta del API
  /// (`"Diamante"`, `"Media Partner"`). Lo desconocido conserva su texto original.
  factory SponsorTier.fromLabel(String? raw) {
    final text = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return otros;
    final key = _normalizeKey(text);
    for (final tier in known) {
      if (tier.key == key) return tier;
    }
    if (key == otros.key) return otros;
    return SponsorTier._(key, text, unknownOrder);
  }

  @override
  bool operator ==(Object other) => other is SponsorTier && other.key == key;

  @override
  int get hashCode => key.hashCode;

  /// Conocidos primero por [order]; entre iguales, alfabético por etiqueta.
  @override
  int compareTo(SponsorTier other) =>
      order != other.order ? order.compareTo(other.order) : label.compareTo(other.label);

  @override
  String toString() => 'SponsorTier($key)';
}

/// Acentos → letra base, para que `Línea Aérea Oficial` y `Linea Aerea Oficial`
/// caigan en un único grupo (y color) en vez de duplicarse.
const _accents = <String, String>{
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ç': 'c',
};

String _normalizeKey(String text) {
  var s = text.toLowerCase();
  _accents.forEach((from, to) => s = s.replaceAll(from, to));
  return s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

/// Patrocinadores de los [levels] niveles **conocidos** más altos que estén
/// presentes en [sponsors] (para la vista previa del home).
///
/// Es data-driven a propósito: si un año no hay Diamante, sube el siguiente nivel
/// solo. Si no hay ningún nivel conocido, cae a los primeros presentes para que la
/// fila del home nunca quede vacía.
List<Sponsor> topTierSponsors(List<Sponsor> sponsors, {int levels = 2}) {
  final present = <SponsorTier>{for (final s in sponsors) s.tier}.toList()..sort();
  var pick = present.where((t) => t.isKnown).take(levels).toSet();
  if (pick.isEmpty) pick = present.take(levels).toSet();
  return sponsors.where((s) => pick.contains(s.tier)).toList();
}

/// Patrocinador del congreso.
class Sponsor {
  final String id;
  final String name;
  final SponsorTier tier;
  final String description;
  final String? logoUrl;
  final String? booth;
  final String? web;
  final String? email;
  final String? phone;

  const Sponsor({
    required this.id,
    required this.name,
    required this.tier,
    this.description = '',
    this.logoUrl,
    this.booth,
    this.web,
    this.email,
    this.phone,
  });

  factory Sponsor.fromJson(Map<String, dynamic> json) {
    return Sponsor(
      id: json['id'] as String,
      name: json['name'] as String,
      tier: SponsorTier.fromLabel(json['tier'] as String?),
      description: json['description'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      booth: json['booth'] as String?,
      web: json['web'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}
