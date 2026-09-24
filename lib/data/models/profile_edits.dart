/// Campos editables del perfil general (`PUT /me`).
///
/// `sector` e `intereses` **no** están aquí a propósito: los escribe
/// `PUT /events/{id}/networking/me` y el backend los excluye de `PUT /me`. Si
/// los mandara también, dos endpoints se pelearían por las mismas columnas con
/// formatos distintos.
typedef ProfileEdits = ({
  String firstName,
  String lastName,
  String company,
  String position,
  String mobile,
  String city,
  String bio,
  String linkedin,
});

/// Tope real de `perfiles.bio` en la base. El backend valida `max:2000` contra
/// una columna `varchar(400)`, así que pasarse devuelve un 500, no un 422.
const int bioMaxLength = 400;

/// Body de `PUT /me`.
///
/// **Omite las claves vacías de los campos NOT NULL** (`nombre`, `apellido`,
/// `empresa`, `cargo`). El backend tiene `ConvertEmptyStringsToNull` activo, así
/// que un `""` llega como `null` a una columna que no lo admite y responde 500.
/// Omitirlas significa "no toques este campo", que es justo lo que quiere quien
/// deja un campo en blanco.
///
/// Los campos que **sí** admiten nulo (`movil`, `ciudad`, `bio`, `linkedin`) se
/// mandan vacíos a propósito: es la única forma de borrarlos.
Map<String, dynamic> profileUpdateBody(ProfileEdits e) {
  final body = <String, dynamic>{};

  void notNull(String key, String value) {
    final v = value.trim();
    if (v.isNotEmpty) body[key] = v;
  }

  notNull('nombre', e.firstName);
  notNull('apellido', e.lastName);
  notNull('empresa', e.company);
  notNull('cargo', e.position);

  body['movil'] = e.mobile.trim();
  body['ciudad'] = e.city.trim();
  body['linkedin'] = e.linkedin.trim();

  final bio = e.bio.trim();
  body['bio'] = bio.length > bioMaxLength ? bio.substring(0, bioMaxLength) : bio;

  return body;
}
