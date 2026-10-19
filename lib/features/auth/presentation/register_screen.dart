import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profile/data/profile_repository.dart';
import '../domain/auth_validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  final _confirmController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  static const Color _darkGreen =
      Color(0xFF063B2B);

  static const Color _mediumGreen =
      Color(0xFF178447);

  static const Color _brightGreen =
      Color(0xFF4DDE78);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();

    super.dispose();
  }

  Future<void> _registerUser() async {
    final isValid =
        _formKey.currentState?.validate() ??
            false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
        email:
            _emailController.text.trim(),
        password:
            _passwordController.text,
      );

      final user = credential.user;

      if (user == null) {
        throw StateError(
          'Firebase no devolvió el usuario creado.',
        );
      }

      final cleanName =
          _nameController.text.trim();

      await user.updateDisplayName(
        cleanName,
      );

      await user.reload();

      final refreshedUser =
          FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        throw StateError(
          'No se pudo recuperar la sesión del usuario recién creado.',
        );
      }

      await ProfileRepository()
          .createInitialProfile(
        refreshedUser,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

      String message =
          'No se pudo crear la cuenta.';

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'Ese correo ya está registrado.';
          break;

        case 'invalid-email':
          message =
              'El correo electrónico no es válido.';
          break;

        case 'weak-password':
          message =
              'La contraseña es demasiado débil.';
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

  void _backToLogin() {
    if (_isLoading) {
      return;
    }

    Navigator.of(context).pop();
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
                begin:
                    Alignment.topCenter,
                end:
                    Alignment.bottomCenter,
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
              builder:
                  (
                context,
                constraints,
              ) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior
                          .onDrag,
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    22,
                    18,
                    22,
                    22,
                  ),
                  child:
                      ConstrainedBox(
                    constraints:
                        BoxConstraints(
                      minHeight:
                          constraints
                                  .maxHeight -
                              40,
                    ),
                    child:
                        IntrinsicHeight(
                      child: Column(
                        children: [
                          _buildBrand(),

                          const SizedBox(
                            height: 16,
                          ),

                          Expanded(
                            child: Center(
                              child:
                                  ConstrainedBox(
                                constraints:
                                    const BoxConstraints(
                                  maxWidth:
                                      520,
                                ),
                                child:
                                    _buildRegisterCard(),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          Text(
                            'Tu temporada empieza aquí',
                            textAlign:
                                TextAlign
                                    .center,
                            style:
                                TextStyle(
                              color: Colors
                                  .white
                                  .withValues(
                                alpha:
                                    0.94,
                              ),
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              fontStyle:
                                  FontStyle
                                      .italic,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            'Crea tu cuenta y forma parte de CanchaYA.',
                            textAlign:
                                TextAlign
                                    .center,
                            style:
                                TextStyle(
                              color: Colors
                                  .white
                                  .withValues(
                                alpha:
                                    0.72,
                              ),
                              fontSize:
                                  13,
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
              fontSize: 40,
              fontWeight:
                  FontWeight.w900,
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

        const SizedBox(
          height: 8,
        ),

        Text(
          'Fútbol, personas y mejores partidos.',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color: Colors.white
                .withValues(
              alpha: 0.90,
            ),
            fontSize: 14,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(
          alpha: 0.97,
        ),
        borderRadius:
            BorderRadius.circular(
          28,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.20,
            ),
            blurRadius: 30,
            offset:
                const Offset(
              0,
              14,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          _buildTabs(),

          const SizedBox(
            height: 18,
          ),

          Form(
            key: _formKey,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                _buildNameField(),

                const SizedBox(
                  height: 12,
                ),

                _buildEmailField(),

                const SizedBox(
                  height: 12,
                ),

                _buildPasswordField(),

                const SizedBox(
                  height: 12,
                ),

                _buildConfirmPasswordField(),

                const SizedBox(
                  height: 18,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 54,
                  child:
                      FilledButton(
                    onPressed:
                        _isLoading
                            ? null
                            : _registerUser,
                    style:
                        FilledButton
                            .styleFrom(
                      backgroundColor:
                          _mediumGreen,
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                                width:
                                    22,
                                height:
                                    22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2.3,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Text(
                                    'Crear cuenta',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          16,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(
                                    width:
                                        10,
                                  ),
                                  Icon(
                                    Icons
                                        .arrow_forward_rounded,
                                    size:
                                        21,
                                  ),
                                ],
                              ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets
                    .all(
              13,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF1F8F3,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                14,
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Icon(
                  Icons
                      .verified_user_outlined,
                  color:
                      _mediumGreen,
                  size: 20,
                ),

                SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Text(
                    'Tu cuenta inicia como Jugador. Los permisos especiales se asignan únicamente mediante invitaciones autorizadas.',
                    style:
                        TextStyle(
                      color:
                          _darkGreen,
                      fontSize:
                          12,
                      height:
                          1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Wrap(
            alignment:
                WrapAlignment
                    .center,
            crossAxisAlignment:
                WrapCrossAlignment
                    .center,
            children: [
              Text(
                '¿Ya tienes cuenta?',
                style:
                    TextStyle(
                  color: Colors
                      .grey
                      .shade700,
                ),
              ),

              TextButton(
                onPressed:
                    _isLoading
                        ? null
                        : _backToLogin,
                child:
                    const Text(
                  'Iniciar sesión',
                  style:
                      TextStyle(
                    color:
                        _darkGreen,
                    fontWeight:
                        FontWeight
                            .w800,
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
          child: InkWell(
            borderRadius:
                BorderRadius
                    .circular(
              12,
            ),
            onTap:
                _backToLogin,
            child: Padding(
              padding:
                  const EdgeInsets
                      .only(
                bottom: 12,
              ),
              child: Text(
                'Iniciar sesión',
                textAlign:
                    TextAlign
                        .center,
                style:
                    TextStyle(
                  color: Colors
                      .grey
                      .shade700,
                  fontWeight:
                      FontWeight
                          .w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(
          width: 18,
        ),

        Expanded(
          child: Column(
            children: [
              const Text(
                'Crear cuenta',
                style:
                    TextStyle(
                  color:
                      _darkGreen,
                  fontWeight:
                      FontWeight
                          .w800,
                  fontSize: 15,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Container(
                height: 2.5,
                decoration:
                    BoxDecoration(
                  color:
                      _mediumGreen,
                  borderRadius:
                      BorderRadius
                          .circular(
                    100,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller:
          _nameController,
      textInputAction:
          TextInputAction.next,
      autofillHints: const [
        AutofillHints.name,
      ],
      validator:
          AuthValidators
              .displayName,
      decoration:
          _inputDecoration(
        hintText:
            'Nombre completo',
        icon:
            Icons.person_outline,
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller:
          _emailController,
      keyboardType:
          TextInputType
              .emailAddress,
      textInputAction:
          TextInputAction.next,
      autofillHints: const [
        AutofillHints.email,
      ],
      autocorrect: false,
      validator:
          AuthValidators.email,
      decoration:
          _inputDecoration(
        hintText:
            'Correo electrónico',
        icon:
            Icons
                .mail_outline_rounded,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller:
          _passwordController,
      obscureText:
          _obscurePassword,
      textInputAction:
          TextInputAction.next,
      autofillHints: const [
        AutofillHints
            .newPassword,
      ],
      validator:
          AuthValidators
              .password,
      decoration:
          _inputDecoration(
        hintText:
            'Contraseña',
        icon:
            Icons
                .lock_outline_rounded,
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
                    .visibility_off_outlined
                : Icons
                    .visibility_outlined,
            color: Colors
                .grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller:
          _confirmController,
      obscureText:
          _obscureConfirm,
      textInputAction:
          TextInputAction.done,
      autofillHints: const [
        AutofillHints
            .newPassword,
      ],
      validator: (value) {
        return AuthValidators
            .confirmPassword(
          value,
          _passwordController
              .text,
        );
      },
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          _registerUser();
        }
      },
      decoration:
          _inputDecoration(
        hintText:
            'Confirmar contraseña',
        icon:
            Icons
                .lock_reset_outlined,
        suffixIcon:
            IconButton(
          tooltip:
              _obscureConfirm
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
                ? Icons
                    .visibility_off_outlined
                : Icons
                    .visibility_outlined,
            color: Colors
                .grey.shade600,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,

      prefixIcon: Icon(
        icon,
        color:
            Colors.grey.shade600,
      ),

      suffixIcon:
          suffixIcon,

      filled: true,

      fillColor:
          const Color(
        0xFFF9FAF9,
      ),

      helperText:
          hintText == 'Contraseña'
              ? '10+ caracteres, mayúscula, minúscula, número y símbolo.'
              : null,

      helperMaxLines: 2,

      helperStyle:
          TextStyle(
        fontSize: 11,
        color:
            Colors.grey.shade600,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius
                .circular(
          14,
        ),
        borderSide:
            BorderSide(
          color:
              Colors.grey
                  .shade300,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius
                .circular(
          14,
        ),
        borderSide:
            BorderSide(
          color:
              Colors.grey
                  .shade300,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius
                .circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color:
              _mediumGreen,
          width: 1.7,
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius
                .circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color:
              Colors.redAccent,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius
                .circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color:
              Colors.redAccent,
          width: 1.7,
        ),
      ),
    );
  }
}