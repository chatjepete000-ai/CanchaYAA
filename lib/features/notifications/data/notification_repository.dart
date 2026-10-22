import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore =
            firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _collectionName =
      'notifications';

  CollectionReference<Map<String, dynamic>>
      get _notificationsCollection {
    return _firestore.collection(
      _collectionName,
    );
  }

  User get _currentUser {
    final user = _auth.currentUser;

    if (user == null) {
      throw const NotificationRepositoryException(
        code: 'not-authenticated',
        message:
            'Necesitas iniciar sesión para consultar tus notificaciones.',
      );
    }

    return user;
  }

  /// Escucha en tiempo real las notificaciones
  /// pertenecientes al usuario autenticado.
  ///
  /// La consulta únicamente solicita documentos
  /// cuyo recipientUserId coincide con el UID actual.
  ///
  /// Aun así, la seguridad definitiva debe estar
  /// respaldada por Firestore Rules.
  Stream<List<AppNotification>>
      watchCurrentUserNotifications({
    int maxItems = 100,
  }) {
    final user = _currentUser;

    final safeLimit =
        _normalizeLimit(
      maxItems,
    );

    return _notificationsCollection
        .where(
          'recipientUserId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(
      (snapshot) {
        final notifications =
            snapshot.docs
                .map(
                  AppNotification
                      .fromFirestore,
                )
                .where(
                  (notification) =>
                      notification
                          .recipientUserId ==
                      user.uid,
                )
                .toList();

        notifications.sort(
          (
            first,
            second,
          ) {
            return second.createdAt.compareTo(
              first.createdAt,
            );
          },
        );

        if (notifications.length <=
            safeLimit) {
          return List<
              AppNotification>.unmodifiable(
            notifications,
          );
        }

        return List<AppNotification>.unmodifiable(
          notifications.take(
            safeLimit,
          ),
        );
      },
    );
  }

  /// Devuelve en tiempo real la cantidad
  /// de notificaciones sin leer.
  Stream<int> watchUnreadCount() {
    return watchCurrentUserNotifications(
      maxItems: 500,
    ).map(
      (notifications) {
        return notifications
            .where(
              (notification) =>
                  notification.unread,
            )
            .length;
      },
    ).distinct();
  }

  /// Obtiene una copia puntual de las
  /// notificaciones más recientes.
  Future<List<AppNotification>>
      getCurrentUserNotifications({
    int maxItems = 100,
  }) async {
    final user = _currentUser;

    final safeLimit =
        _normalizeLimit(
      maxItems,
    );

    try {
      final snapshot =
          await _notificationsCollection
              .where(
                'recipientUserId',
                isEqualTo: user.uid,
              )
              .get();

      final notifications =
          snapshot.docs
              .map(
                AppNotification.fromFirestore,
              )
              .where(
                (notification) =>
                    notification
                        .recipientUserId ==
                    user.uid,
              )
              .toList();

      notifications.sort(
        (
          first,
          second,
        ) {
          return second.createdAt.compareTo(
            first.createdAt,
          );
        },
      );

      return List<AppNotification>.unmodifiable(
        notifications.take(
          safeLimit,
        ),
      );
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(
        error,
      );
    }
  }

  /// Obtiene una notificación concreta
  /// únicamente si pertenece al usuario actual.
  Future<AppNotification?>
      getNotificationById(
    String notificationId,
  ) async {
    final user = _currentUser;

    final cleanId =
        notificationId.trim();

    if (cleanId.isEmpty) {
      throw const NotificationRepositoryException(
        code: 'invalid-notification-id',
        message:
            'La notificación no es válida.',
      );
    }

    try {
      final snapshot =
          await _notificationsCollection
              .doc(
                cleanId,
              )
              .get();

      if (!snapshot.exists) {
        return null;
      }

      final notification =
          AppNotification.fromFirestore(
        snapshot,
      );

      if (notification.recipientUserId !=
          user.uid) {
        throw const NotificationRepositoryException(
          code: 'permission-denied',
          message:
              'No tienes permiso para consultar esta notificación.',
        );
      }

      return notification;
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(
        error,
      );
    }
  }

  /// Marca una notificación como leída.
  ///
  /// Antes de actualizarla verifica en el
  /// cliente que realmente pertenezca al usuario.
  /// Firestore Rules deberá repetir esta misma
  /// comprobación del lado del servidor.
  Future<void> markAsRead(
    String notificationId,
  ) async {
    final user = _currentUser;

    final cleanId =
        notificationId.trim();

    if (cleanId.isEmpty) {
      throw const NotificationRepositoryException(
        code: 'invalid-notification-id',
        message:
            'La notificación no es válida.',
      );
    }

    try {
      final reference =
          _notificationsCollection.doc(
        cleanId,
      );

      final snapshot =
          await reference.get();

      if (!snapshot.exists) {
        throw const NotificationRepositoryException(
          code: 'notification-not-found',
          message:
              'La notificación ya no está disponible.',
        );
      }

      final notification =
          AppNotification.fromFirestore(
        snapshot,
      );

      if (notification.recipientUserId !=
          user.uid) {
        throw const NotificationRepositoryException(
          code: 'permission-denied',
          message:
              'No tienes permiso para modificar esta notificación.',
        );
      }

      if (notification.isRead) {
        return;
      }

      await reference.update(
        <String, dynamic>{
          'isRead': true,
          'readAt':
              FieldValue.serverTimestamp(),
        },
      );
    } on NotificationRepositoryException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(
        error,
      );
    }
  }

  /// Marca todas las notificaciones del
  /// usuario actual como leídas.
  ///
  /// Se utilizan lotes pequeños para no
  /// superar el límite de escrituras de
  /// un WriteBatch de Firestore.
  Future<int> markAllAsRead() async {
    final user = _currentUser;

    try {
      final snapshot =
          await _notificationsCollection
              .where(
                'recipientUserId',
                isEqualTo: user.uid,
              )
              .get();

      final unreadDocuments =
          snapshot.docs.where(
        (document) {
          final notification =
              AppNotification.fromFirestore(
            document,
          );

          return notification
                      .recipientUserId ==
                  user.uid &&
              notification.unread;
        },
      ).toList();

      if (unreadDocuments.isEmpty) {
        return 0;
      }

      const batchSize = 400;

      var processed = 0;

      for (var start = 0;
          start <
              unreadDocuments.length;
          start += batchSize) {
        final end =
            (start + batchSize) >
                    unreadDocuments.length
                ? unreadDocuments.length
                : start + batchSize;

        final batch =
            _firestore.batch();

        for (var index = start;
            index < end;
            index++) {
          final document =
              unreadDocuments[index];

          batch.update(
            document.reference,
            <String, dynamic>{
              'isRead': true,
              'readAt':
                  FieldValue.serverTimestamp(),
            },
          );

          processed++;
        }

        await batch.commit();
      }

      return processed;
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(
        error,
      );
    }
  }

  /// Devuelve solamente las notificaciones
  /// todavía no leídas del usuario actual.
  Future<List<AppNotification>>
      getUnreadNotifications() async {
    final notifications =
        await getCurrentUserNotifications(
      maxItems: 500,
    );

    return List<AppNotification>.unmodifiable(
      notifications.where(
        (notification) =>
            notification.unread,
      ),
    );
  }

  /// Por seguridad NO incluimos aquí un método
  /// genérico como createNotification().
  ///
  /// La aplicación cliente no debe poder
  /// fabricar notificaciones arbitrarias para
  /// otros usuarios.
  ///
  /// La creación real se conectará después
  /// a acciones autorizadas o a un servicio
  /// confiable encargado del envío push.

  int _normalizeLimit(
    int value,
  ) {
    if (value < 1) {
      return 1;
    }

    if (value > 500) {
      return 500;
    }

    return value;
  }

  NotificationRepositoryException
      _mapFirebaseException(
    FirebaseException error,
  ) {
    switch (error.code) {
      case 'permission-denied':
        return const NotificationRepositoryException(
          code: 'permission-denied',
          message:
              'No tienes permiso para consultar o modificar estas notificaciones.',
        );

      case 'unauthenticated':
        return const NotificationRepositoryException(
          code: 'not-authenticated',
          message:
              'Tu sesión ya no está activa. Inicia sesión nuevamente.',
        );

      case 'unavailable':
        return const NotificationRepositoryException(
          code: 'service-unavailable',
          message:
              'El servicio de notificaciones no está disponible temporalmente.',
        );

      case 'deadline-exceeded':
        return const NotificationRepositoryException(
          code: 'timeout',
          message:
              'La operación tardó demasiado. Intenta nuevamente.',
        );

      case 'failed-precondition':
        return const NotificationRepositoryException(
          code: 'failed-precondition',
          message:
              'Firestore necesita una configuración adicional para completar esta operación.',
        );

      case 'resource-exhausted':
        return const NotificationRepositoryException(
          code: 'resource-exhausted',
          message:
              'El servicio está temporalmente ocupado. Intenta nuevamente más tarde.',
        );

      case 'cancelled':
        return const NotificationRepositoryException(
          code: 'cancelled',
          message:
              'La operación fue cancelada.',
        );

      default:
        return const NotificationRepositoryException(
          code: 'notification-operation-failed',
          message:
              'No se pudo completar la operación de notificaciones.',
        );
    }
  }
}

class NotificationRepositoryException
    implements Exception {
  const NotificationRepositoryException({
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