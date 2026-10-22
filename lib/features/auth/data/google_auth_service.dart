import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static Future<void>? _initialization;

  Future<void> signIn() async {
    final auth = FirebaseAuth.instance;
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      await auth.signInWithPopup(provider);
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      throw UnsupportedError('Google no está disponible en esta plataforma.');
    }

    final google = GoogleSignIn.instance;
    await (_initialization ??= google.initialize());
    final account = await google.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    await auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  }
}
