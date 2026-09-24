import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/data/models/models.dart';

/// Estas omisiones no son cosméticas: el backend tiene `ConvertEmptyStringsToNull`
/// activo y `nombre`/`apellido`/`empresa`/`cargo` son NOT NULL, así que mandar
/// `""` responde 500. Ver `docs/API-PENDIENTES.md` §A5.
void main() {
  ProfileEdits edits({
    String firstName = 'Ana',
    String lastName = 'Ríos',
    String company = 'Avícola',
    String position = 'Gerente',
    String mobile = '',
    String city = '',
    String bio = '',
    String linkedin = '',
  }) => (
    firstName: firstName, lastName: lastName, company: company,
    position: position, mobile: mobile, city: city, bio: bio, linkedin: linkedin,
  );

  group('profileUpdateBody', () {
    test('manda los campos rellenos con espacios recortados', () {
      final b = profileUpdateBody(edits(firstName: '  Ana  '));
      expect(b['nombre'], 'Ana');
      expect(b['apellido'], 'Ríos');
      expect(b['empresa'], 'Avícola');
      expect(b['cargo'], 'Gerente');
    });

    test('OMITE los NOT NULL vacíos en vez de mandar cadena vacía', () {
      final b = profileUpdateBody(edits(company: '', position: '   '));
      expect(b.containsKey('empresa'), isFalse);
      expect(b.containsKey('cargo'), isFalse);
      // Los que sí admiten nulo viajan vacíos: es cómo se borran.
      expect(b['ciudad'], '');
      expect(b['movil'], '');
      expect(b['linkedin'], '');
    });

    test('todos los NOT NULL vacíos → ninguna de esas claves viaja', () {
      final b = profileUpdateBody(
        edits(firstName: '', lastName: '', company: '', position: ''),
      );
      for (final k in ['nombre', 'apellido', 'empresa', 'cargo']) {
        expect(b.containsKey(k), isFalse, reason: '$k no debe viajar vacío');
      }
    });

    test('recorta la bio al tope REAL de la columna, no al del validate', () {
      final larga = 'x' * 1500; // el backend valida max:2000 sobre varchar(400)
      final b = profileUpdateBody(edits(bio: larga));
      expect((b['bio'] as String).length, bioMaxLength);
      expect(bioMaxLength, 400);
    });

    test('una bio corta se manda entera', () {
      expect(profileUpdateBody(edits(bio: 'Hola'))['bio'], 'Hola');
    });
  });

  group('AppUser.name derivado', () {
    test('une nombre y apellido', () {
      const u = AppUser(
        id: '1', firstName: 'Ana', lastName: 'Ríos',
        position: '', company: '', email: '',
      );
      expect(u.name, 'Ana Ríos');
    });

    test('sin apellido no deja espacio colgando', () {
      const u = AppUser(
        id: '1', firstName: 'Ana', lastName: '',
        position: '', company: '', email: '',
      );
      expect(u.name, 'Ana');
    });

    test('copyWith conserva lo no tocado', () {
      const u = AppUser(
        id: '1', firstName: 'Ana', lastName: 'Ríos',
        position: 'Gerente', company: 'Avícola', email: 'a@b.com',
      );
      final v = u.copyWith(position: 'Directora');
      expect(v.name, 'Ana Ríos');
      expect(v.position, 'Directora');
      expect(v.email, 'a@b.com');
    });
  });
}
