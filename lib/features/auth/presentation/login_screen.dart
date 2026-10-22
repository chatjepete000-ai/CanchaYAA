import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/google_auth_service.dart';

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

  static const Color _darkGreen = Color(0xFF063B2B);
  static const Color _mediumGreen = Color(0xFF178447);
  static const Color _brightGreen = Color(0xFF4DDE78);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    final isValid =
        _formKey.currentState?.validate() ?? false;

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

      // app.dart escucha authStateChanges().
      // Cuando Firebase detecta la sesión,
      // automáticamente mostrará HomeShell.
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
          message =
              'No existe una cuenta registrada con ese correo.';
          break;

        case 'wrong-password':
          message = 'La contraseña es incorrecta.';
          break;

        case 'invalid-credential':
          message =
              'El correo o la contraseña son incorrectos.';
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
      await FirebaseAuth.instance.setLanguageCode('es');
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Si existe una cuenta asociada a $email, recibirás un enlace para cambiar tu contraseña. Revisa tu bandeja de entrada y spam.',
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
        case 'user-not-found':
          message = 'Si existe una cuenta asociada a $email, recibirás un enlace para cambiar tu contraseña. Revisa tu bandeja de entrada y spam.';
          break;

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

  void _openRegister() {
    if (_isLoading) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await GoogleAuthService().signIn();
      // app.dart waits for the profile and then displays HomeShell.
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return;
      _showAuthMessage(
        error.code == GoogleSignInExceptionCode.clientConfigurationError
            ? 'El acceso con Google aún no está configurado. Contacta al administrador.'
            : 'No se pudo conectar con Google. Revisa tu conexión e inténtalo nuevamente.',
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        return;
      }
      final message = switch (error.code) {
        'account-exists-with-different-credential' =>
          'Este correo ya utiliza otro método de acceso. Inicia sesión con ese método.',
        'user-disabled' => 'Esta cuenta ha sido deshabilitada.',
        'network-request-failed' => 'Revisa tu conexión a internet e inténtalo nuevamente.',
        'popup-blocked' => 'Permite las ventanas emergentes para continuar con Google.',
        'operation-not-allowed' || 'unauthorized-domain' =>
          'El acceso con Google aún no está configurado. Contacta al administrador.',
        'too-many-requests' => 'Demasiados intentos. Espera un momento e inténtalo nuevamente.',
        _ => 'No se pudo iniciar sesión con Google. Inténtalo nuevamente.',
      };
      _showAuthMessage(message);
    } on UnsupportedError catch (_) {
      _showAuthMessage('Usa Android o la versión web para continuar con Google.');
    } catch (_) {
      _showAuthMessage('No se pudo iniciar sesión con Google. Inténtalo nuevamente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAuthMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/auth/login_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x22000000),
                  Color(0x3300140D),
                  Color(0x8802281C),
                  Color(0xCC022218),
                ],
                stops: [
                  0.0,
                  0.35,
                  0.72,
                  1.0,
                ],
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    22,
                    20,
                    22,
                    22,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 42,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          _buildBrand(),

                          const SizedBox(height: 18),

                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: _buildLoginCard(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Text(
                            'La cancha te espera',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: 0.94,
                              ),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Equipos, torneos y mejores partidos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: 0.72,
                              ),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.8,
              height: 1,
            ),
            children: [
              TextSpan(
                text: 'Cancha',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: 'YA',
                style: TextStyle(
                  color: _brightGreen,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 9),

        Text(
          'Fútbol, personas y mejores partidos.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(
              alpha: 0.90,
            ),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.97,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.20,
            ),
            blurRadius: 30,
            offset: const Offset(
              0,
              14,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabs(),

          const SizedBox(height: 22),

          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmailField(),

                const SizedBox(height: 13),

                _buildPasswordField(),

                const SizedBox(height: 2),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : _showPasswordResetDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: _darkGreen,
                    ),
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed:
                        _isLoading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: _mediumGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(
                                Icons
                                    .arrow_forward_rounded,
                                size: 21,
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildSeparator(),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : _loginWithGoogle,
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(0xFF202020),
                side: BorderSide(
                  color: Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),
              child: const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  _GoogleMark(),
                  SizedBox(width: 11),
                  Text(
                    'Continuar con Google',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            children: [
              Text(
                '¿No tienes cuenta?',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              TextButton(
                onPressed:
                    _isLoading ? null : _openRegister,
                child: const Text(
                  'Crear cuenta',
                  style: TextStyle(
                    color: _darkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              const Text(
                'Iniciar sesión',
                style: TextStyle(
                  color: _darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 10),

              Container(
                height: 2.5,
                decoration: BoxDecoration(
                  color: _mediumGreen,
                  borderRadius:
                      BorderRadius.circular(100),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 18),

        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openRegister,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: Text(
                'Crear cuenta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [
        AutofillHints.email,
      ],
      textInputAction: TextInputAction.next,
      autocorrect: false,
      validator: AuthValidators.email,
      decoration: InputDecoration(
        hintText: 'Correo electrónico',
        prefixIcon: Icon(
          Icons.mail_outline_rounded,
          color: Colors.grey.shade600,
        ),
        filled: true,
        fillColor: const Color(
          0xFFF9FAF9,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _mediumGreen,
            width: 1.7,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      autofillHints: const [
        AutofillHints.password,
      ],
      textInputAction: TextInputAction.done,
      // Existing credentials may follow a different password policy, including
      // passwords created by Firebase's hosted reset page.
      validator: (value) => (value == null || value.isEmpty)
          ? 'Ingresa tu contraseña'
          : null,
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          _login();
        }
      },
      decoration: InputDecoration(
        hintText: 'Contraseña',
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: Colors.grey.shade600,
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
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey.shade600,
          ),
        ),
        filled: true,
        fillColor: const Color(
          0xFFF9FAF9,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _mediumGreen,
            width: 1.7,
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Text(
            'o continúa con',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),

        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
          ),
        ),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(
            0xFFE5E5E5,
          ),
        ),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(
            0xFF4285F4,
          ),
        ),
      ),
    );
  }
}

class PasswordResetDialog
    extends StatefulWidget {
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

    _emailController = TextEditingController(
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
        _formKey.currentState?.validate() ?? false;

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe el correo asociado a tu cuenta. '
              'Te enviaremos un enlace para crear una nueva contraseña de CanchaYA. '
              'Puedes recibirlo en Gmail u otro servicio de correo. Revisa también spam.',
            ),

            const SizedBox(height: 18),

            TextFormField(
              controller: _emailController,
              keyboardType:
                  TextInputType.emailAddress,
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
              validator: AuthValidators.email,
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