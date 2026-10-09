import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/auth_validators.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sesión iniciada correctamente.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      String message = 'No se pudo iniciar sesión.';

      switch (e.code) {
        case 'invalid-email':
          message = 'El correo electrónico no es válido.';
          break;

        case 'user-disabled':
          message = 'Esta cuenta ha sido deshabilitada.';
          break;

        case 'user-not-found':
          message = 'No existe una cuenta registrada con ese correo.';
          break;

        case 'wrong-password':
          message = 'La contraseña es incorrecta.';
          break;

        case 'invalid-credential':
          message = 'El correo o la contraseña son incorrectos.';
          break;

        case 'too-many-requests':
          message =
              'Se hicieron demasiados intentos. Espera un momento e inténtalo nuevamente.';
          break;

        case 'network-request-failed':
          message =
              'No se pudo conectar con Firebase. Revisa tu conexión a internet.';
          break;

        case 'operation-not-allowed':
          message =
              'El inicio de sesión con correo y contraseña no está habilitado.';
          break;

        default:
          message =
              'No se pudo iniciar sesión. Código: ${e.code}';
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
            'Ocurrió un error inesperado al iniciar sesión.',
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

  Future<void> _showPasswordResetDialog() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) {
        return PasswordResetDialog(
          initialEmail: _emailController.text.trim(),
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (email == null || email.trim().isEmpty) {
      return;
    }

    await _sendPasswordResetEmail(
      email.trim(),
    );
  }

  Future<void> _sendPasswordResetEmail(
    String email,
  ) async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Si existe una cuenta asociada a $email, recibirás un correo para cambiar tu contraseña.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      String message =
          'No se pudo enviar el correo de recuperación.';

      switch (e.code) {
        case 'invalid-email':
          message =
              'El correo electrónico no es válido.';
          break;

        case 'user-disabled':
          message =
              'Esta cuenta está deshabilitada.';
          break;

        case 'too-many-requests':
          message =
              'Se hicieron demasiados intentos. Espera un momento antes de volver a intentarlo.';
          break;

        case 'network-request-failed':
          message =
              'No se pudo conectar con Firebase. Revisa tu conexión a internet.';
          break;

        default:
          message =
              'No se pudo enviar el correo. Código: ${e.code}';
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
            'Ocurrió un error inesperado al intentar recuperar la contraseña.',
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
        title: const Text(
          'Iniciar sesión',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.sports_soccer,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),

            const SizedBox(height: 18),

            Text(
              'Bienvenido a CanchaYA',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Accede con tu correo y contraseña.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.email,
                    ],
                    textInputAction:
                        TextInputAction.next,
                    decoration:
                        const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                      ),
                    ),
                    validator:
                        AuthValidators.email,
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller:
                        _passwordController,
                    obscureText:
                        _obscurePassword,
                    autofillHints: const [
                      AutofillHints.password,
                    ],
                    textInputAction:
                        TextInputAction.done,
                    decoration:
                        InputDecoration(
                      labelText:
                          'Contraseña',
                      prefixIcon:
                          const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon:
                          IconButton(
                        tooltip:
                            _obscurePassword
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
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator:
                        AuthValidators.password,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _login();
                      }
                    },
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment:
                        Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          _isLoading
                              ? null
                              : _showPasswordResetDialog,
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child:
                        FilledButton.icon(
                      onPressed:
                          _isLoading
                              ? null
                              : _login,
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
                              Icons.login,
                            ),
                      label: Text(
                        _isLoading
                            ? 'Procesando...'
                            : 'Entrar',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const RegisterScreen(),
                        ),
                      );
                    },
              child: const Text(
                '¿No tienes cuenta? Crear cuenta',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordResetDialog extends StatefulWidget {
  const PasswordResetDialog({
    super.key,
    required this.initialEmail,
  });

  final String initialEmail;

  @override
  State<PasswordResetDialog> createState() =>
      _PasswordResetDialogState();
}

class _PasswordResetDialogState
    extends State<PasswordResetDialog> {
  final _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _emailController;

  @override
  void initState() {
    super.initState();

    _emailController =
        TextEditingController(
      text: widget.initialEmail,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final isValid =
        _formKey.currentState
                ?.validate() ??
            false;

    if (!isValid) {
      return;
    }

    Navigator.of(context).pop(
      _emailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(
            Icons.lock_reset_outlined,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Recuperar contraseña',
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe el correo asociado a tu cuenta. '
              'Te enviaremos un enlace para crear una nueva contraseña.',
            ),

            const SizedBox(height: 18),

            TextFormField(
              controller:
                  _emailController,
              keyboardType:
                  TextInputType
                      .emailAddress,
              textInputAction:
                  TextInputAction.done,
              autofocus: true,
              decoration:
                  const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(
                  Icons.email_outlined,
                ),
              ),
              validator:
                  AuthValidators.email,
              onFieldSubmitted:
                  (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancelar',
          ),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(
            Icons.send_outlined,
          ),
          label: const Text(
            'Enviar enlace',
          ),
        ),
      ],
    );
  }
}