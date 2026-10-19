import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/domain/user_role.dart';
import '../data/cloudinary_profile_photo_service.dart';
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

  final _photoService =
      CloudinaryProfilePhotoService();

  final _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  late FootballPosition _position;

  bool _saving = false;
  bool _uploadingPhoto = false;

  String _photoUrl = '';

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

    _photoUrl = widget.profile.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  bool get _isDesktop {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform ==
            TargetPlatform.windows ||
        defaultTargetPlatform ==
            TargetPlatform.macOS ||
        defaultTargetPlatform ==
            TargetPlatform.linux;
  }

  Future<bool> _showPhotoPermissionDialog() async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          icon: Icon(
            _isDesktop
                ? CupertinoIcons.folder
                : CupertinoIcons.photo_on_rectangle,
            color: colors.primary,
            size: 34,
          ),
          title: Text(
            _isDesktop
                ? 'Seleccionar una fotografía'
                : 'Acceso a tus fotografías',
            textAlign: TextAlign.center,
          ),
          content: Text(
            _isDesktop
                ? 'CanchaYA abrirá el explorador de archivos para que elijas una fotografía desde tu computadora.'
                : 'CanchaYA necesita que selecciones una fotografía de tu dispositivo para usarla como foto de perfil.\n\nSolo tendremos acceso a la imagen que tú elijas.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              icon: Icon(
                _isDesktop
                    ? CupertinoIcons.folder_open
                    : CupertinoIcons.photo,
              ),
              label: Text(
                _isDesktop
                    ? 'Abrir archivos'
                    : 'Seleccionar foto',
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_uploadingPhoto) {
      return;
    }

    final allowed =
        await _showPhotoPermissionDialog();

    if (!allowed || !mounted) {
      return;
    }

    XFile? image;

    try {
      image =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,

        // Reduce un poco el peso
        // sin afectar demasiado la calidad.
        imageQuality: 85,

        // Evita subir fotografías gigantes.
        maxWidth: 1200,
        maxHeight: 1200,

        requestFullMetadata: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isDesktop
                ? 'No se pudo abrir el explorador de archivos: $error'
                : 'No se pudo abrir el selector de fotografías: $error',
          ),
        ),
      );

      return;
    }

    // El usuario cerró el selector
    // sin escoger fotografía.
    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _uploadingPhoto = true;
    });

    try {
      final uploadedUrl =
          await _photoService.uploadProfilePhoto(
        image,
      );

      await _repository.updateProfilePhoto(
        uploadedUrl,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _photoUrl = uploadedUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto de perfil actualizada correctamente.',
          ),
        ),
      );
    } on CloudinaryProfilePhotoException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar la fotografía: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final isValid =
        _formKey.currentState?.validate() ??
            false;

    if (!isValid) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _repository.updateCurrentProfile(
        displayName:
            _nameController.text,
        phone:
            _phoneController.text,
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
    final colors =
        Theme.of(context).colorScheme;

    final hasPhoto =
        _photoUrl.trim().isNotEmpty;

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
            padding:
                const EdgeInsets.all(20),
            children: [
              Container(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                decoration: BoxDecoration(
                  color:
                      colors.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(
                    22,
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior:
                          Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor:
                              colors.primary,
                          foregroundImage:
                              hasPhoto
                                  ? NetworkImage(
                                      _photoUrl,
                                    )
                                  : null,
                          child: hasPhoto
                              ? null
                              : Icon(
                                  CupertinoIcons
                                      .person_fill,
                                  size: 42,
                                  color: colors
                                      .onPrimary,
                                ),
                        ),

                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Material(
                            color:
                                colors.primary,
                            shape:
                                const CircleBorder(),
                            child: InkWell(
                              customBorder:
                                  const CircleBorder(),
                              onTap:
                                  _uploadingPhoto
                                      ? null
                                      : _pickAndUploadPhoto,
                              child: SizedBox(
                                width: 38,
                                height: 38,
                                child: Center(
                                  child:
                                      _uploadingPhoto
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth:
                                                    2,
                                                color:
                                                    colors.onPrimary,
                                              ),
                                            )
                                          : Icon(
                                              _isDesktop
                                                  ? CupertinoIcons.folder_fill
                                                  : CupertinoIcons.camera_fill,
                                              size: 18,
                                              color:
                                                  colors.onPrimary,
                                            ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    const Text(
                      'Foto de perfil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      _uploadingPhoto
                          ? 'Subiendo fotografía...'
                          : _isDesktop
                              ? 'Toca la carpeta para elegir una imagen de tu computadora.'
                              : 'Toca la cámara para elegir una imagen de tu galería.',
                      textAlign:
                          TextAlign.center,
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    OutlinedButton.icon(
                      onPressed:
                          _uploadingPhoto
                              ? null
                              : _pickAndUploadPhoto,
                      icon: Icon(
                        _isDesktop
                            ? CupertinoIcons
                                .folder_open
                            : CupertinoIcons
                                .photo_on_rectangle,
                      ),
                      label: Text(
                        hasPhoto
                            ? 'Cambiar fotografía'
                            : 'Agregar fotografía',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              TextFormField(
                controller:
                    _nameController,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(
                    CupertinoIcons.person,
                  ),
                ),
                validator: (value) {
                  final cleanValue =
                      value?.trim() ?? '';

                  if (cleanValue.isEmpty) {
                    return 'Escribe tu nombre.';
                  }

                  if (cleanValue.length <
                      2) {
                    return 'El nombre es demasiado corto.';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                    _phoneController,
                keyboardType:
                    TextInputType.phone,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText: 'Teléfono',
                  hintText: 'Opcional',
                  prefixIcon: Icon(
                    CupertinoIcons.phone,
                  ),
                ),
                validator: (value) {
                  final cleanValue =
                      value?.trim() ?? '';

                  if (cleanValue.isEmpty) {
                    return null;
                  }

                  final phone =
                      cleanValue.replaceAll(
                    RegExp(
                      r'[^0-9+]',
                    ),
                    '',
                  );

                  if (phone.length < 8) {
                    return 'El teléfono parece demasiado corto.';
                  }

                  if (phone.length >
                      16) {
                    return 'El teléfono parece demasiado largo.';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 14,
              ),

              DropdownButtonFormField<
                  FootballPosition>(
                initialValue:
                    _position,
                decoration:
                    const InputDecoration(
                  labelText: 'Posición',
                  prefixIcon: Icon(
                    CupertinoIcons
                        .sportscourt,
                  ),
                ),
                items: FootballPosition
                    .values
                    .map(
                  (position) {
                    return DropdownMenuItem<
                        FootballPosition>(
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
                        if (value ==
                            null) {
                          return;
                        }

                        setState(() {
                          _position =
                              value;
                        });
                      },
              ),

              const SizedBox(
                height: 24,
              ),

              FilledButton.icon(
                onPressed:
                    _saving ||
                            _uploadingPhoto
                        ? null
                        : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons
                            .check_mark_circled,
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
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                decoration: BoxDecoration(
                  color: colors
                      .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Icon(
                      CupertinoIcons
                          .shield,
                    ),
                    SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Text(
                        'Aquí puedes cambiar tu información personal, fotografía y posición futbolística. Los permisos de Jugador, Capitán o Administrador no se pueden modificar desde el perfil.',
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