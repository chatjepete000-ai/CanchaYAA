import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profile/data/profile_repository.dart';
import '../domain/auth_validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();

    super.dispose();
  }

  Future<void> _registerUser() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;

      if (user == null) {
        throw StateError(
          'Firebase no devolvió el usuario creado.',
        );
      }

      final cleanName = _nameController.text.trim();

      // Guardamos el nombre también en Firebase Authentication.
      await user.updateDisplayName(
        cleanName,
      );

      // Recargamos la información del usuario.
      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        throw StateError(
          'No se pudo recuperar la sesión del usuario recién creado.',
        );
      }

      // Creamos el perfil real en Firestore.
      await ProfileRepository().createInitialProfile(
        refreshedUser,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuenta creada correctamente.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      String message = 'No se pudo crear la cuenta.';

      switch (e.code) {
        case 'email-already-in-use':
          message = 'Ese correo ya está registrado.';
          break;

        case 'invalid-email':
          message = 'El correo electrónico no es válido.';
          break;

        case 'weak-password':
          message = 'La contraseña es demasiado débil.';
          break;

        case 'operation-not-allowed':
          message =
              'El registro con correo y contraseña no está habilitado.';
          break;

        case 'network-request-failed':
          message =
              'No se pudo conectar con Firebase. Revisa tu conexión a internet.';
          break;

        case 'too-many-requests':
          message =
              'Se hicieron demasiados intentos. Espera un momento e inténtalo nuevamente.';
          break;

        default:
          message =
              'No se pudo crear la cuenta. Código: ${e.code}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
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
            'La cuenta se creó, pero hubo un problema al guardar el perfil: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          'Crear cuenta',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
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
                        Icons.sports_soccer,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Únete a CanchaYA',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Crea tu cuenta para participar en equipos, torneos e invitaciones.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              Text(
                'Crea tu perfil',
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
              ),

              const SizedBox(height: 6),

              Text(
                'Todos los usuarios comienzan como Jugador.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.name,
                ],
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(
                    Icons.person_outline,
                  ),
                ),
                validator: AuthValidators.displayName,
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                  ),
                ),
                validator: AuthValidators.email,
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.newPassword,
                ],
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  helperText:
                      '10+ caracteres, mayúscula, minúscula, número y símbolo.',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () {
                      setState(() {
                        _obscurePassword =
                            !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: AuthValidators.password,
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                autofillHints: const [
                  AutofillHints.newPassword,
                ],
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: const Icon(
                    Icons.lock_reset_outlined,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirm
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () {
                      setState(() {
                        _obscureConfirm =
                            !_obscureConfirm;
                      });
                    },
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  return AuthValidators.confirmPassword(
                    value,
                    _passwordController.text,
                  );
                },
                onFieldSubmitted: (_) {
                  if (!_isLoading) {
                    _registerUser();
                  }
                },
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed:
                    _isLoading ? null : _registerUser,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.person_add_alt_1,
                      ),
                label: Text(
                  _isLoading
                      ? 'Creando cuenta...'
                      : 'Crear cuenta',
                ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      colors.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.security_outlined,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tu cuenta se crea como Jugador. Los permisos de Capitán y Administrador se asignan de forma controlada y no pueden elegirse durante el registro.',
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