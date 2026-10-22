import 'package:firebase_auth/firebase_auth.dart';

class AccountSecurityRepository {
  AccountSecurityRepository({
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User get _currentUser {
    final user = _auth.currentUser;

    if (user == null) {
      throw const AccountSecurityException(
        code: 'no-authenticated-user',
        message:
            'Tu sesión ya no está activa. Inicia sesión nuevamente.',
      );
    }

    return user;
  }

  String get currentEmail {
    return _auth.currentUser?.email?.trim() ?? '';
  }

  bool get hasAuthenticatedUser {
    return _auth.currentUser != null;
  }

  bool get usesPasswordProvider {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    return user.providerData.any(
      (provider) =>
          provider.providerId ==
          EmailAuthProvider.PROVIDER_ID,
    );
  }

  Future<void> reauthenticateWithPassword({
    required String currentPassword,
  }) async {
    final user = _currentUser;

    final email =
        user.email?.trim().toLowerCase() ?? '';

    if (email.isEmpty) {
      throw const AccountSecurityException(
        code: 'missing-email',
        message:
            'Esta cuenta no tiene un correo disponible para verificar tu identidad.',
      );
    }

    if (!usesPasswordProvider) {
      throw const AccountSecurityException(
        code: 'unsupported-provider',
        message:
            'Esta cuenta no utiliza contraseña como método de acceso.',
      );
    }

    if (currentPassword.isEmpty) {
      throw const AccountSecurityException(
        code: 'missing-current-password',
        message:
            'Escribe tu contraseña actual para continuar.',
      );
    }

    try {
      final credential =
          EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(
        credential,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _validateNewPassword(
      newPassword,
    );

    if (currentPassword == newPassword) {
      throw const AccountSecurityException(
        code: 'same-password',
        message:
            'La nueva contraseña debe ser diferente a la contraseña actual.',
      );
    }

    await reauthenticateWithPassword(
      currentPassword: currentPassword,
    );

    final user = _currentUser;

    try {
      await user.updatePassword(
        newPassword,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _currentUser;

    final currentEmail =
        user.email?.trim().toLowerCase() ?? '';

    final cleanNewEmail =
        newEmail.trim().toLowerCase();

    _validateEmail(
      cleanNewEmail,
    );

    if (currentEmail.isNotEmpty &&
        currentEmail == cleanNewEmail) {
      throw const AccountSecurityException(
        code: 'same-email',
        message:
            'El nuevo correo debe ser diferente al correo actual.',
      );
    }

    await reauthenticateWithPassword(
      currentPassword: currentPassword,
    );

    try {
      await user.verifyBeforeUpdateEmail(
        cleanNewEmail,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<void> sendPasswordResetToCurrentEmail() async {
    final email =
        _currentUser.email?.trim() ?? '';

    if (email.isEmpty) {
      throw const AccountSecurityException(
        code: 'missing-email',
        message:
            'Esta cuenta no tiene un correo disponible.',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(
        email: email,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<void> reloadCurrentUser() async {
    final user = _currentUser;

    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  void _validateEmail(
    String email,
  ) {
    if (email.isEmpty) {
      throw const AccountSecurityException(
        code: 'empty-email',
        message:
            'Escribe el nuevo correo electrónico.',
      );
    }

    if (email.length > 254) {
      throw const AccountSecurityException(
        code: 'invalid-email',
        message:
            'El correo electrónico no es válido.',
      );
    }

    final emailExpression = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailExpression.hasMatch(email)) {
      throw const AccountSecurityException(
        code: 'invalid-email',
        message:
            'Escribe un correo electrónico válido.',
      );
    }
  }

  void _validateNewPassword(
    String password,
  ) {
    if (password.length < 10) {
      throw const AccountSecurityException(
        code: 'weak-password',
        message:
            'La contraseña debe tener al menos 10 caracteres.',
      );
    }

    if (password.length > 128) {
      throw const AccountSecurityException(
        code: 'password-too-long',
        message:
            'La contraseña es demasiado larga.',
      );
    }

    final hasUppercase =
        RegExp(r'[A-Z]').hasMatch(password);

    final hasLowercase =
        RegExp(r'[a-z]').hasMatch(password);

    final hasNumber =
        RegExp(r'[0-9]').hasMatch(password);

    final hasSymbol =
        RegExp(
          r'[!@#$%^&*(),.?":{}|<>_\-+=;:/\\\[\]~`]',
        ).hasMatch(password);

    if (!hasUppercase ||
        !hasLowercase ||
        !hasNumber ||
        !hasSymbol) {
      throw const AccountSecurityException(
        code: 'weak-password',
        message:
            'Usa al menos una mayúscula, una minúscula, un número y un símbolo.',
      );
    }
  }

  AccountSecurityException _mapFirebaseException(
    FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return const AccountSecurityException(
          code: 'invalid-credential',
          message:
              'La contraseña actual no es correcta.',
        );

      case 'requires-recent-login':
        return const AccountSecurityException(
          code: 'requires-recent-login',
          message:
              'Por seguridad necesitas verificar nuevamente tu identidad.',
        );

      case 'weak-password':
        return const AccountSecurityException(
          code: 'weak-password',
          message:
              'La nueva contraseña no cumple con los requisitos de seguridad.',
        );

      case 'invalid-email':
        return const AccountSecurityException(
          code: 'invalid-email',
          message:
              'El correo electrónico no es válido.',
        );

      case 'email-already-in-use':
        return const AccountSecurityException(
          code: 'email-already-in-use',
          message:
              'Ese correo ya está asociado a otra cuenta.',
        );

      case 'user-disabled':
        return const AccountSecurityException(
          code: 'user-disabled',
          message:
              'Esta cuenta está deshabilitada.',
        );

      case 'user-not-found':
        return const AccountSecurityException(
          code: 'user-not-found',
          message:
              'No se pudo verificar la cuenta actual.',
        );

      case 'network-request-failed':
        return const AccountSecurityException(
          code: 'network-request-failed',
          message:
              'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
        );

      case 'too-many-requests':
        return const AccountSecurityException(
          code: 'too-many-requests',
          message:
              'Se realizaron demasiados intentos. Intenta nuevamente más tarde.',
        );

      case 'operation-not-allowed':
        return const AccountSecurityException(
          code: 'operation-not-allowed',
          message:
              'Esta operación no está disponible para esta cuenta.',
        );

      default:
        return const AccountSecurityException(
          code: 'security-operation-failed',
          message:
              'No se pudo completar la operación de seguridad. Intenta nuevamente.',
        );
    }
  }
}

class AccountSecurityException
    implements Exception {
  const AccountSecurityException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() {
    return message;
  }
}