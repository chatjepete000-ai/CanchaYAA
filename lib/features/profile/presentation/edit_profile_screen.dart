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

    _nameController = TextEditingController(
      text: widget.profile.displayName,
    );

    _phoneController = TextEditingController(
      text: widget.profile.phone,
    );

    _position = widget.profile.position;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _repository.updateCurrentProfile(
        displayName: _nameController.text,
        phone: _phoneController.text,
        position: _position,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Perfil actualizado correctamente.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar el perfil: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Editar perfil',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colors.primary,
                      child: Icon(
                        Icons.person_outline,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información del jugador',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(
                            height: 4,
                          ),
                          Text(
                            'Actualiza tus datos y tu posición en cancha.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(
                    Icons.person_outline,
                  ),
                ),
                validator: (value) {
                  final cleanValue = value?.trim() ?? '';

                  if (cleanValue.isEmpty) {
                    return 'Escribe tu nombre.';
                  }

                  if (cleanValue.length < 2) {
                    return 'El nombre es demasiado corto.';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  hintText: 'Opcional',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                  ),
                ),
                validator: (value) {
                  final cleanValue = value?.trim() ?? '';

                  if (cleanValue.isEmpty) {
                    return null;
                  }

                  final phone = cleanValue.replaceAll(
                    RegExp(r'[^0-9+]'),
                    '',
                  );

                  if (phone.length < 8) {
                    return 'El teléfono parece demasiado corto.';
                  }

                  if (phone.length > 16) {
                    return 'El teléfono parece demasiado largo.';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 14,
              ),

              DropdownButtonFormField<FootballPosition>(
                initialValue: _position,
                decoration: const InputDecoration(
                  labelText: 'Posición',
                  prefixIcon: Icon(
                    Icons.sports_soccer_outlined,
                  ),
                ),
                items: FootballPosition.values.map(
                  (position) {
                    return DropdownMenuItem<FootballPosition>(
                      value: position,
                      child: Text(
                        position.label,
                      ),
                    );
                  },
                ).toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _position = value;
                        });
                      },
              ),

              const SizedBox(
                height: 24,
              ),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save_outlined,
                      ),
                label: Text(
                  _saving
                      ? 'Guardando...'
                      : 'Guardar cambios',
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.security_outlined,
                    ),
                    SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Text(
                        'Aquí puedes cambiar tu información personal y tu posición futbolística. Los permisos de Jugador, Capitán o Administrador no se pueden modificar desde el perfil.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}