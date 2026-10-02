abstract final class AuthValidators {
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ingresa tu correo';

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(text)) return 'Correo no válido';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Ingresa tu contraseña';
    if (text.length < 10) return 'Usa al menos 10 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(text)) {
      return 'Agrega al menos una mayúscula';
    }
    if (!RegExp(r'[a-z]').hasMatch(text)) {
      return 'Agrega al menos una minúscula';
    }
    if (!RegExp(r'[0-9]').hasMatch(text)) {
      return 'Agrega al menos un número';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(text)) {
      return 'Agrega al menos un símbolo';
    }
    return null;
  }

  static String? displayName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ingresa tu nombre';
    if (text.length < 3) return 'Escribe al menos 3 caracteres';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Confirma tu contraseña';
    if (value != original) return 'Las contraseñas no coinciden';
    return null;
  }
}
