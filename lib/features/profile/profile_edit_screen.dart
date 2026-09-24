import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers/user_provider.dart';

/// Edición del perfil general contra `PUT /me`.
///
/// **No edita `sector` ni intereses**: los escribe el perfil de networking
/// (`PUT /events/{id}/networking/me`) y el backend los excluye de aquí a
/// propósito. Tenerlos en dos sitios sería que dos endpoints se peleen por las
/// mismas columnas.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final AppUser _user = ref.read(currentUserProvider) ?? AppUser.guest;

  late final _firstName = TextEditingController(text: _user.firstName);
  late final _lastName = TextEditingController(text: _user.lastName);
  late final _position = TextEditingController(text: _user.position);
  late final _company = TextEditingController(text: _user.company);
  late final _mobile = TextEditingController(text: _user.mobile ?? '');
  late final _city = TextEditingController(text: _user.city);
  late final _linkedin = TextEditingController(text: _user.socials.linkedin ?? '');
  late final _bio = TextEditingController(text: _user.bio);

  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _position, _company,
      _mobile, _city, _linkedin, _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(authControllerProvider.notifier).updateProfile((
        firstName: _firstName.text,
        lastName: _lastName.text,
        company: _company.text,
        position: _position.text,
        mobile: _mobile.text,
        city: _city.text,
        bio: _bio.text,
        linkedin: _linkedin.text,
      ));
      if (!mounted) return;
      // El toast solo después de que el servidor lo confirme: antes decía
      // "Perfil actualizado" sin haber guardado nada.
      messenger.showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'No se pudo guardar el perfil.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _field('Nombre', _firstName),
          _field('Apellido', _lastName),
          _field('Cargo', _position),
          _field('Empresa', _company),
          _field('Móvil', _mobile, keyboard: TextInputType.phone),
          _field('Ciudad', _city),
          _field('LinkedIn', _linkedin, keyboard: TextInputType.url),
          // La bio la leen otros asistentes: con el contenido de usuario apagado
          // (App Store 1.2) nadie puede verla, así que editarla no tendría
          // sentido. Ver `AppConfig.userContent`.
          if (AppConfig.userContent)
            _field('Biografía', _bio, maxLines: 4, maxLength: bioMaxLength),
          const SizedBox(height: 8),
          Text(
            'Tus sectores e intereses se editan en tu perfil de networking.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            // Tope real de la columna en la base, no el del `validate()`.
            maxLength: maxLength,
            keyboardType: keyboard,
            textCapitalization: keyboard == null
                ? TextCapitalization.sentences
                : TextCapitalization.none,
          ),
        ],
      ),
    );
  }
}
