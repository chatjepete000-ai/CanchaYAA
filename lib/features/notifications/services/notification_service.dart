import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  static const String highImportanceChannelId =
      'canchaya_high_importance';

  static const String highImportanceChannelName =
      'CanchaYA - Avisos importantes';

  static const String highImportanceChannelDescription =
      'Resultados, cambios de horario, cambios de cancha, '
      'partidos pospuestos y recordatorios importantes.';

  static const AndroidNotificationChannel
      highImportanceChannel =
      AndroidNotificationChannel(
    highImportanceChannelId,
    highImportanceChannelName,
    description: highImportanceChannelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FirebaseInstallations _installations =
      FirebaseInstallations.instance;

  final FlutterLocalNotificationsPlugin
      _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>>
      _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<User?>? _authSubscription;

  StreamSubscription<String>?
      _tokenRefreshSubscription;

  StreamSubscription<String>?
      _installationIdSubscription;

  StreamSubscription<RemoteMessage>?
      _foregroundMessageSubscription;

  StreamSubscription<RemoteMessage>?
      _openedMessageSubscription;

  bool _initialized = false;

  Map<String, dynamic>?
      _initialNotificationData;

  Stream<Map<String, dynamic>>
      get notificationTapStream =>
          _notificationTapController.stream;

  bool get isInitialized =>
      _initialized;

  bool get _supportsNativePush {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform ==
            TargetPlatform.android ||
        defaultTargetPlatform ==
            TargetPlatform.iOS ||
        defaultTargetPlatform ==
            TargetPlatform.macOS;
  }

  bool get _isAndroid =>
      !kIsWeb &&
      defaultTargetPlatform ==
          TargetPlatform.android;

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform ==
              TargetPlatform.iOS ||
          defaultTargetPlatform ==
              TargetPlatform.macOS);

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (!_supportsNativePush) {
      return;
    }

    if (Firebase.apps.isEmpty) {
      throw StateError(
        'Firebase debe inicializarse antes de NotificationService.',
      );
    }

    _initialized = true;

    try {
      await _initializeLocalNotifications();

      if (_isApplePlatform) {
        await _messaging
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _configureMessagingListeners();

      await _loadInitialNotification();

      _authSubscription =
          _auth.authStateChanges().listen(
        (user) {
          if (user != null) {
            unawaited(
              _prepareSignedInUser(),
            );
          }
        },
      );
    } catch (_) {
      _initialized = false;
      rethrow;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings =
        InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse:
          _handleLocalNotificationTap,
    );

    if (_isAndroid) {
      final androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin
          ?.createNotificationChannel(
        highImportanceChannel,
      );
    }
  }

  Future<void> _prepareSignedInUser() async {
    try {
      await requestPermission();
      await syncCurrentDevice();
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'No se pudo preparar el dispositivo '
          'para notificaciones.',
        );
      }
    }
  }

  Future<bool> requestPermission() async {
    if (!_supportsNativePush) {
      return false;
    }

    final settings =
        await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return _isAuthorized(
      settings.authorizationStatus,
    );
  }

  Future<void> syncCurrentDevice({
    String? refreshedToken,
  }) async {
    if (!_supportsNativePush) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final installationId =
        await _installations.getId();

    final token =
        refreshedToken ??
            await _messaging.getToken();

    if (installationId.trim().isEmpty ||
        token == null ||
        token.trim().isEmpty) {
      return;
    }

    final permissionSettings =
        await _messaging
            .getNotificationSettings();

    final authorizationStatus =
        permissionSettings
            .authorizationStatus;

    final enabled =
        _isAuthorized(
      authorizationStatus,
    );

    final deviceReference =
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('pushDevices')
            .doc(installationId);

    await _firestore.runTransaction(
      (transaction) async {
        final snapshot =
            await transaction.get(
          deviceReference,
        );

        final data =
            <String, dynamic>{
          'userId': user.uid,
          'installationId':
              installationId,
          'fcmToken': token,
          'platform': _platformName(),
          'enabled': enabled,
          'permissionStatus':
              authorizationStatus.name,
          'lastSeenAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        };

        if (!snapshot.exists) {
          data['createdAt'] =
              FieldValue.serverTimestamp();
        }

        transaction.set(
          deviceReference,
          data,
          SetOptions(
            merge: true,
          ),
        );
      },
    );
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_supportsNativePush) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final installationId =
        await _installations.getId();

    if (installationId.trim().isEmpty) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pushDevices')
        .doc(installationId)
        .delete();
  }

  void _configureMessagingListeners() {
    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(
      (message) {
        if (_isAndroid) {
          unawaited(
            _showForegroundNotification(
              message,
            ),
          );
        }
      },
    );

    _openedMessageSubscription =
        FirebaseMessaging
            .onMessageOpenedApp
            .listen(
      (message) {
        _emitNotificationTap(
          _messagePayload(message),
        );
      },
    );

    _tokenRefreshSubscription =
        _messaging.onTokenRefresh.listen(
      (newToken) {
        unawaited(
          syncCurrentDevice(
            refreshedToken: newToken,
          ),
        );
      },
    );

    _installationIdSubscription =
        _installations.onIdChange.listen(
      (_) {
        unawaited(
          syncCurrentDevice(),
        );
      },
    );
  }

  Future<void> _loadInitialNotification() async {
    final remoteMessage =
        await _messaging
            .getInitialMessage();

    if (remoteMessage != null) {
      _initialNotificationData =
          _messagePayload(
        remoteMessage,
      );
    }

    final localLaunchDetails =
        await _localNotifications
            .getNotificationAppLaunchDetails();

    if (localLaunchDetails
                ?.didNotificationLaunchApp ==
            true &&
        localLaunchDetails
                ?.notificationResponse
                ?.payload !=
            null) {
      final payload =
          localLaunchDetails!
              .notificationResponse!
              .payload!;

      final decoded =
          _decodePayload(
        payload,
      );

      if (decoded.isNotEmpty) {
        _initialNotificationData =
            decoded;
      }
    }
  }

  Map<String, dynamic>?
      takeInitialNotificationData() {
    final data =
        _initialNotificationData;

    _initialNotificationData =
        null;

    return data;
  }

  Future<void>
      _showForegroundNotification(
    RemoteMessage message,
  ) async {
    final remoteNotification =
        message.notification;

    final title =
        remoteNotification?.title ??
            _stringValue(
              message.data['title'],
            );

    final body =
        remoteNotification?.body ??
            _stringValue(
              message.data['body'],
            );

    if (title.isEmpty &&
        body.isEmpty) {
      return;
    }

    const androidDetails =
        AndroidNotificationDetails(
      highImportanceChannelId,
      highImportanceChannelName,
      channelDescription:
          highImportanceChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails =
        NotificationDetails(
      android: androidDetails,
    );

    final payload =
        jsonEncode(
      _messagePayload(message),
    );

    await _localNotifications.show(
      id: _notificationId(
        message,
      ),
      title: title.isEmpty
          ? 'CanchaYA'
          : title,
      body: body.isEmpty
          ? null
          : body,
      notificationDetails:
          notificationDetails,
      payload: payload,
    );
  }

  void _handleLocalNotificationTap(
    NotificationResponse response,
  ) {
    final payload =
        response.payload;

    if (payload == null ||
        payload.trim().isEmpty) {
      return;
    }

    final data =
        _decodePayload(
      payload,
    );

    if (data.isNotEmpty) {
      _emitNotificationTap(
        data,
      );
    }
  }

  void _emitNotificationTap(
    Map<String, dynamic> data,
  ) {
    if (data.isEmpty) {
      return;
    }

    if (!_notificationTapController
        .isClosed) {
      _notificationTapController.add(
        data,
      );
    }
  }

  Map<String, dynamic> _messagePayload(
    RemoteMessage message,
  ) {
    final data =
        <String, dynamic>{
      ...message.data,
    };

    final messageId =
        message.messageId;

    if (messageId != null &&
        messageId.isNotEmpty) {
      data['messageId'] =
          messageId;
    }

    final title =
        message.notification?.title;

    if (title != null &&
        title.isNotEmpty &&
        !data.containsKey('title')) {
      data['title'] = title;
    }

    final body =
        message.notification?.body;

    if (body != null &&
        body.isNotEmpty &&
        !data.containsKey('body')) {
      data['body'] = body;
    }

    return data;
  }

  Map<String, dynamic> _decodePayload(
    String payload,
  ) {
    try {
      final decoded =
          jsonDecode(payload);

      if (decoded
          is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return decoded.map(
          (key, value) =>
              MapEntry(
            key.toString(),
            value,
          ),
        );
      }
    } catch (_) {
      return <String, dynamic>{};
    }

    return <String, dynamic>{};
  }

  int _notificationId(
    RemoteMessage message,
  ) {
    final source =
        message.messageId ??
            '${DateTime.now().microsecondsSinceEpoch}';

    return source.hashCode &
        0x7fffffff;
  }

  bool _isAuthorized(
    AuthorizationStatus status,
  ) {
    return status ==
            AuthorizationStatus
                .authorized ||
        status ==
            AuthorizationStatus
                .provisional;
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String _stringValue(
    Object? value,
  ) {
    return value
            ?.toString()
            .trim() ??
        '';
  }

  Future<void> dispose() async {
    await _authSubscription
        ?.cancel();

    await _tokenRefreshSubscription
        ?.cancel();

    await _installationIdSubscription
        ?.cancel();

    await _foregroundMessageSubscription
        ?.cancel();

    await _openedMessageSubscription
        ?.cancel();

    await _notificationTapController
        .close();

    _initialized = false;
  }
}