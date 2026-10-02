import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

      await credential.user?.updateDisplayName(
        _nameController.text.trim(),
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
          message = 'No se pudo crear la cuenta. Código: ${e.code}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ocurrió un error inesperado al crear la cuenta.',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Crea tu perfil',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'El acceso base será con correo y contraseña.',
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.name,
                ],
                decoration: const InputDecoration(
                  labelText: 'Nombre',
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
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
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
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
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

              const SizedBox(height: 22),

              FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        _registerUser();
                      },
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.person_add_alt_1,
                      ),
                label: Text(
                  _isLoading ? 'Creando cuenta...' : 'Crear cuenta',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}