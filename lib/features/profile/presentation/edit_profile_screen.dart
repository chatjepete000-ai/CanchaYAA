import 'package:flutter/material.dart';

import '../../auth/domain/user_role.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ProfileRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late FootballPosition _position;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _phoneController = TextEditingController(text: widget.profile.phone);
    _position = widget.profile.position;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await _repository.updateCurrentProfile(
        displayName: _nameController.text,
        phone: _phoneController.text,
        position: _position,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el perfil: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                final clean = value?.trim() ?? '';
                if (clean.length < 2) return 'Escribe tu nombre.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                final clean = (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
                if (clean.isEmpty) return null;
                if (clean.length < 8 || clean.length > 16) {
                  return 'Revisa el número de teléfono.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<FootballPosition>(
              initialValue: _position,
              decoration: const InputDecoration(
                labelText: 'Posición',
                prefixIcon: Icon(Icons.sports_soccer_outlined),
              ),
              items: FootballPosition.values
                  .map(
                    (position) => DropdownMenuItem(
                      value: position,
                      child: Text(position.label),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _position = value);
                    },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tu posición futbolística sí la puedes cambiar. Los permisos de Jugador, Capitán y Administrador no se modifican desde el perfil.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
