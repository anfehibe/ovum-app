import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../data/models/models.dart';
import '../../data/providers/user_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final AppUser _user = ref.read(currentUserProvider) ?? AppUser.guest;
  late final _name = TextEditingController(text: _user.name);
  late final _position = TextEditingController(text: _user.position);
  late final _company = TextEditingController(text: _user.company);
  late final _city = TextEditingController(text: _user.city);
  late final _sector = TextEditingController(text: _user.sector);
  late final _bio = TextEditingController(text: _user.bio);

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    _company.dispose();
    _city.dispose();
    _sector.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(authControllerProvider.notifier).updateUser(
          _user.copyWith(
            name: _name.text.trim(),
            position: _position.text.trim(),
            company: _company.text.trim(),
            city: _city.text.trim(),
            sector: _sector.text.trim(),
            bio: _bio.text.trim(),
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil actualizado')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _field('Nombre', _name),
          _field('Cargo', _position),
          _field('Empresa', _company),
          _field('Ciudad', _city),
          _field('Sector', _sector),
          _field('Biografía', _bio, maxLines: 4),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text(AppStrings.save)),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {int maxLines = 1}) {
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
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
