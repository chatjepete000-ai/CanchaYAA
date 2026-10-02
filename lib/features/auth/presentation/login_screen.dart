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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión iniciada correctamente.')),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

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
        case 'invalid-credential':
          message = 'El correo o la contraseña son incorrectos.';
          break;
        case 'too-many-requests':
          message = 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
          break;
        case 'network-request-failed':
          message = 'No se pudo conectar con Firebase. Revisa tu conexión.';
          break;
        case 'operation-not-allowed':
          message = 'El inicio de sesión con correo y contraseña no está habilitado.';
          break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final emailController = TextEditingController(text: _emailController.text);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (AuthValidators.email(email) != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Escribe un correo válido.')),
                );
                return;
              }

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Si el correo está registrado, recibirás instrucciones para restablecer la contraseña.',
                    ),
                  ),
                );
              } on FirebaseAuthException catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No se pudo enviar el correo: ${error.code}',
                    ),
                  ),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: AuthValidators.email,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: AuthValidators.password,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _login();
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _login,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        _isLoading ? 'Iniciando sesión...' : 'Entrar',
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
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
              child: const Text('¿No tienes cuenta? Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
