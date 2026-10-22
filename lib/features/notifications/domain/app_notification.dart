import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  teamInvitation,
  invitationAccepted,
  invitationRejected,
  teamUpdate,
  matchCreated,
  matchUpdated,
  matchReminder,
  tournamentUpdate,
  resultPublished,
  system,
}

extension AppNotificationTypeX
    on AppNotificationType {
  String get value {
    switch (this) {
      case AppNotificationType.teamInvitation:
        return 'team_invitation';

      case AppNotificationType.invitationAccepted:
        return 'invitation_accepted';

      case AppNotificationType.invitationRejected:
        return 'invitation_rejected';

      case AppNotificationType.teamUpdate:
        return 'team_update';

      case AppNotificationType.matchCreated:
        return 'match_created';

      case AppNotificationType.matchUpdated:
        return 'match_updated';

      case AppNotificationType.matchReminder:
        return 'match_reminder';

      case AppNotificationType.tournamentUpdate:
        return 'tournament_update';

      case AppNotificationType.resultPublished:
        return 'result_published';

      case AppNotificationType.system:
        return 'system';
    }
  }

  String get label {
    switch (this) {
      case AppNotificationType.teamInvitation:
        return 'Invitación a equipo';

      case AppNotificationType.invitationAccepted:
        return 'Invitación aceptada';

      case AppNotificationType.invitationRejected:
        return 'Invitación rechazada';

      case AppNotificationType.teamUpdate:
        return 'Equipo';

      case AppNotificationType.matchCreated:
        return 'Nuevo partido';

      case AppNotificationType.matchUpdated:
        return 'Partido actualizado';

      case AppNotificationType.matchReminder:
        return 'Recordatorio de partido';

      case AppNotificationType.tournamentUpdate:
        return 'Torneo';

      case AppNotificationType.resultPublished:
        return 'Resultado publicado';

      case AppNotificationType.system:
        return 'CanchaYA';
    }
  }

  static AppNotificationType fromValue(
    String? value,
  ) {
    switch (value) {
      case 'team_invitation':
        return AppNotificationType.teamInvitation;

      case 'invitation_accepted':
        return AppNotificationType.invitationAccepted;

      case 'invitation_rejected':
        return AppNotificationType.invitationRejected;

      case 'team_update':
        return AppNotificationType.teamUpdate;

      case 'match_created':
        return AppNotificationType.matchCreated;

      case 'match_updated':
        return AppNotificationType.matchUpdated;

      case 'match_reminder':
        return AppNotificationType.matchReminder;

      case 'tournament_update':
        return AppNotificationType.tournamentUpdate;

      case 'result_published':
        return AppNotificationType.resultPublished;

      case 'system':
      default:
        return AppNotificationType.system;
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.senderUserId,
    this.teamId,
    this.tournamentId,
    this.matchId,
    this.invitationId,
    this.route,
    this.data = const <String, dynamic>{},
  });

  final String id;

  /// Usuario que debe recibir la notificación.
  final String recipientUserId;

  /// Título visible.
  final String title;

  /// Mensaje visible.
  final String body;

  final AppNotificationType type;

  /// Indica si el usuario ya abrió o marcó
  /// la notificación como leída.
  final bool isRead;

  /// Fecha en que se creó la notificación.
  final DateTime createdAt;

  /// Fecha en que fue marcada como leída.
  final DateTime? readAt;

  /// Usuario que originó la acción, cuando aplica.
  final String? senderUserId;

  /// Relaciones opcionales.
  final String? teamId;
  final String? tournamentId;
  final String? matchId;
  final String? invitationId;

  /// Ruta lógica opcional para navegación.
  ///
  /// Ejemplos:
  /// team
  /// tournament
  /// match
  /// invitations
  final String? route;

  /// Información extra no sensible necesaria
  /// para procesar la navegación.
  final Map<String, dynamic> data;

  bool get unread => !isRead;

  bool get hasTeam =>
      teamId != null &&
      teamId!.trim().isNotEmpty;

  bool get hasTournament =>
      tournamentId != null &&
      tournamentId!.trim().isNotEmpty;

  bool get hasMatch =>
      matchId != null &&
      matchId!.trim().isNotEmpty;

  bool get hasInvitation =>
      invitationId != null &&
      invitationId!.trim().isNotEmpty;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>>
        document,
  ) {
    final json =
        document.data() ??
            const <String, dynamic>{};

    return AppNotification(
      id: document.id,
      recipientUserId:
          _readString(
        json['recipientUserId'],
      ),
      title:
          _readString(
        json['title'],
      ),
      body:
          _readString(
        json['body'],
      ),
      type:
          AppNotificationTypeX.fromValue(
        _readNullableString(
          json['type'],
        ),
      ),
      isRead:
          json['isRead'] == true,
      createdAt:
          _readDateTime(
        json['createdAt'],
      ),
      readAt:
          _readNullableDateTime(
        json['readAt'],
      ),
      senderUserId:
          _readNullableString(
        json['senderUserId'],
      ),
      teamId:
          _readNullableString(
        json['teamId'],
      ),
      tournamentId:
          _readNullableString(
        json['tournamentId'],
      ),
      matchId:
          _readNullableString(
        json['matchId'],
      ),
      invitationId:
          _readNullableString(
        json['invitationId'],
      ),
      route:
          _readNullableString(
        json['route'],
      ),
      data:
          _readMap(
        json['data'],
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'recipientUserId':
          recipientUserId,
      'title':
          title,
      'body':
          body,
      'type':
          type.value,
      'isRead':
          isRead,
      'createdAt':
          Timestamp.fromDate(
        createdAt,
      ),
      'readAt':
          readAt == null
              ? null
              : Timestamp.fromDate(
                  readAt!,
                ),
      'senderUserId':
          _emptyToNull(
        senderUserId,
      ),
      'teamId':
          _emptyToNull(
        teamId,
      ),
      'tournamentId':
          _emptyToNull(
        tournamentId,
      ),
      'matchId':
          _emptyToNull(
        matchId,
      ),
      'invitationId':
          _emptyToNull(
        invitationId,
      ),
      'route':
          _emptyToNull(
        route,
      ),
      'data':
          data,
    };
  }

  AppNotification copyWith({
    String? id,
    String? recipientUserId,
    String? title,
    String? body,
    AppNotificationType? type,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    bool clearReadAt = false,
    String? senderUserId,
    bool clearSenderUserId = false,
    String? teamId,
    bool clearTeamId = false,
    String? tournamentId,
    bool clearTournamentId = false,
    String? matchId,
    bool clearMatchId = false,
    String? invitationId,
    bool clearInvitationId = false,
    String? route,
    bool clearRoute = false,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id:
          id ??
              this.id,
      recipientUserId:
          recipientUserId ??
              this.recipientUserId,
      title:
          title ??
              this.title,
      body:
          body ??
              this.body,
      type:
          type ??
              this.type,
      isRead:
          isRead ??
              this.isRead,
      createdAt:
          createdAt ??
              this.createdAt,
      readAt:
          clearReadAt
              ? null
              : readAt ??
                  this.readAt,
      senderUserId:
          clearSenderUserId
              ? null
              : senderUserId ??
                  this.senderUserId,
      teamId:
          clearTeamId
              ? null
              : teamId ??
                  this.teamId,
      tournamentId:
          clearTournamentId
              ? null
              : tournamentId ??
                  this.tournamentId,
      matchId:
          clearMatchId
              ? null
              : matchId ??
                  this.matchId,
      invitationId:
          clearInvitationId
              ? null
              : invitationId ??
                  this.invitationId,
      route:
          clearRoute
              ? null
              : route ??
                  this.route,
      data:
          data ??
              this.data,
    );
  }

  static String _readString(
    dynamic value,
  ) {
    if (value is! String) {
      return '';
    }

    return value.trim();
  }

  static String? _readNullableString(
    dynamic value,
  ) {
    if (value is! String) {
      return null;
    }

    final clean =
        value.trim();

    if (clean.isEmpty) {
      return null;
    }

    return clean;
  }

  static DateTime _readDateTime(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed =
          DateTime.tryParse(
        value,
      );

      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime
        .fromMillisecondsSinceEpoch(
      0,
    );
  }

  static DateTime? _readNullableDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;
  }

  static Map<String, dynamic> _readMap(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(
        value,
      );
    }

    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map(
          (
            key,
            mapValue,
          ) =>
              MapEntry(
            key.toString(),
            mapValue,
          ),
        ),
      );
    }

    return const <String, dynamic>{};
  }

  static String? _emptyToNull(
    String? value,
  ) {
    if (value == null) {
      return null;
    }

    final clean =
        value.trim();

    if (clean.isEmpty) {
      return null;
    }

    return clean;
  }
}