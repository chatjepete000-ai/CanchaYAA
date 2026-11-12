import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/notifications/services/match_alert_service.dart';
import 'features/notifications/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  NotificationService.registerBackgroundHandler();

  await NotificationService.instance.initialize();

  // F06: recordatorios de partidos y avisos en tiempo real.
  // Si falla (por ejemplo, permisos), la app sigue funcionando.
  try {
    await MatchAlertService.instance.start();
  } catch (_) {}

  runApp(const CanchaYaApp());
}