import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../teams/data/public_team_repository.dart';
import '../../teams/data/team_match_repository.dart';
import '../../teams/domain/public_team.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';
import '../domain/match_alerts.dart';
import 'match_crest_image.dart';

// ================================================================
// F06 · AVISOS Y RECORDATORIOS EN EL TELÉFONO
// ================================================================
//
// Sin servidor ni plan Blaze:
//
// 1) TIEMPO REAL: escucha la bandeja del usuario
//    (notifications/ con su UID). Cuando el administrador programa,
//    cambia o publica un partido, el aviso llega al instante y se
//    muestra como notificación del sistema con los escudos de ambos
//    equipos (mientras la app está abierta o en segundo plano).
//
// 2) RECORDATORIOS: para cada partido programado de los equipos del
//    usuario agenda avisos locales 24 h antes, 1 h antes y al
//    inicio. Suenan aunque la app esté cerrada. Si el partido
//    cambia, se reprograman (mismo ID = no se duplican); si se
//    pospone o termina, se cancelan.
//
// 3) BANDEJA: los recordatorios que ya sonaron se registran en la
//    bandeja (campanita) al abrir la app, con un ID determinista
//    para que no se repitan.
//
// Al tocar cualquier aviso se abre la bandeja (route: notifications).
// ================================================================

class MatchAlertService {
  MatchAlertService._();

  static final MatchAlertService instance = MatchAlertService._();

  static const String channelId = 'canchaya_match_alerts';
  static const String channelName = 'CanchaYA - Partidos';
  static const String channelDescription =
      'Recordatorios de tus partidos, cambios de horario y resultados.';

  static const String _payloadKind = 'canchaya_match_alert';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final PublicTeamRepository _publicTeams = PublicTeamRepository();
  final TeamMatchRepository _matchRepository = TeamMatchRepository();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _assignmentSubscription;
  StreamSubscription<List<AppNotification>>? _inboxSubscription;
  final Map<String, StreamSubscription<List<TeamMatchSummary>>>
      _matchSubscriptions = {};

  final Map<String, List<TeamMatchSummary>> _matchesByTeam = {};
  final Set<String> _myTeamIds = {};
  final Set<String> _seenInbox = {};
  final Set<String> _registeredReminders = {};
  final Map<String, PublicTeam?> _teamCache = {};

  Timer? _syncDebounce;
  bool _inboxPrimed = false;
  bool _started = false;
  String? _userId;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Se llama una vez al iniciar la app (después de
  /// NotificationService.initialize).
  Future<void> start() async {
    if (_started || !_supported) {
      return;
    }

    _started = true;

    tzdata.initializeTimeZones();

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        if (user?.uid == _userId) {
          return;
        }

        _stopUserListeners();
        _userId = user?.uid;

        if (user == null) {
          // Al cerrar sesión no deben quedar recordatorios de otra
          // cuenta en el teléfono.
          unawaited(_cancelAllMatchReminders());
          return;
        }

        _listenToMyTeams(user.uid);
        _listenToInbox();
      },
    );
  }

  // ==============================================================
  // EQUIPOS Y PARTIDOS DEL USUARIO
  // ==============================================================

  void _listenToMyTeams(String userId) {
    _assignmentSubscription = FirebaseFirestore.instance
        .collection('teamAssignments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
      (snapshot) {
        final active = <String, String>{};

        for (final doc in snapshot.docs) {
          final data = doc.data();

          if (data['status'] != 'active') continue;

          final teamId = (data['teamId'] as String?) ?? '';
          final tournamentId = (data['tournamentId'] as String?) ?? '';

          if (teamId.isNotEmpty && tournamentId.isNotEmpty) {
            active[teamId] = tournamentId;
          }
        }

        _myTeamIds
          ..clear()
          ..addAll(active.keys);

        // Quitar equipos que el usuario ya no tiene.
        for (final teamId in _matchSubscriptions.keys.toList()) {
          if (!active.containsKey(teamId)) {
            _matchSubscriptions.remove(teamId)?.cancel();
            _matchesByTeam.remove(teamId);
          }
        }

        // Escuchar partidos de equipos nuevos.
        active.forEach((teamId, tournamentId) {
          if (_matchSubscriptions.containsKey(teamId)) return;

          _matchSubscriptions[teamId] = _matchRepository
              .watchMatchesForTeam(
                tournamentId: tournamentId,
                teamId: teamId,
              )
              .listen(
            (matches) {
              _matchesByTeam[teamId] = matches;
              _scheduleSync();
            },
            onError: (Object error) => _log('partidos', error),
          );
        });

        _scheduleSync();
      },
      onError: (Object error) => _log('equipos', error),
    );
  }

  void _scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(
      const Duration(seconds: 2),
      () => unawaited(_syncReminders()),
    );
  }

  Future<void> _syncReminders() async {
    final userId = _userId;

    if (userId == null) return;

    final now = DateTime.now();
    final matches = <String, TeamMatchSummary>{
      for (final list in _matchesByTeam.values)
        for (final match in list) match.id: match,
    };

    final pending = await _plugin.pendingNotificationRequests();
    final pendingById = <int, Map<String, dynamic>>{};

    for (final request in pending) {
      final payload = _decode(request.payload);

      if (payload['kind'] == _payloadKind) {
        pendingById[request.id] = payload;
      }
    }

    final wanted = <int>{};

    for (final match in matches.values) {
      final startsAt = match.startsAt;

      if (!match.isScheduled || startsAt == null) continue;

      final signature = _signature(match);

      for (final kind in upcomingReminders(startsAt, now)) {
        final id = reminderNotificationId(match.id, kind);
        wanted.add(id);

        // Ya está programado igual: no se vuelve a programar.
        if (pendingById[id]?['sig'] == signature) continue;

        await _scheduleReminder(match, kind, id, signature);
      }

      for (final kind in dueReminders(startsAt, now)) {
        await _registerReminderInInbox(match, kind, userId);
      }
    }

    // Cancelar los de partidos pospuestos, terminados o que ya no
    // son del usuario.
    for (final id in pendingById.keys) {
      if (!wanted.contains(id)) {
        await _plugin.cancel(id: id);
      }
    }
  }

  String _signature(TeamMatchSummary match) =>
      '${match.startsAt?.toUtc().millisecondsSinceEpoch}|${match.courtId}';

  ({String mine, String rival, PublicTeam? home, PublicTeam? away})
      _sides(TeamMatchSummary match, PublicTeam? home, PublicTeam? away) {
    final homeName = home?.displayName ?? match.homeTeamName;
    final awayName = away?.displayName ?? match.awayTeamName;
    final iAmHome = _myTeamIds.contains(match.homeTeamId);

    return (
      mine: iAmHome ? homeName : awayName,
      rival: iAmHome ? awayName : homeName,
      home: home,
      away: away,
    );
  }

  Future<void> _scheduleReminder(
    TeamMatchSummary match,
    MatchReminderKind kind,
    int id,
    String signature,
  ) async {
    final startsAt = match.startsAt!;
    final home = await _team(match.homeTeamId);
    final away = await _team(match.awayTeamId);
    final sides = _sides(match, home, away);

    final image = await MatchCrestImage.build(
      homeName: home?.displayName ?? match.homeTeamName,
      awayName: away?.displayName ?? match.awayTeamName,
      homeLogoUrl: home?.logoUrl ?? '',
      awayLogoUrl: away?.logoUrl ?? '',
    );

    final title = matchupTitle(sides.mine, sides.rival);
    final body = reminderShortBody(
      kind: kind,
      startsAt: startsAt,
      courtName: match.courtName ?? '',
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(
          reminderFireTime(startsAt, kind),
          tz.UTC,
        ),
        // Sin permiso de alarmas exactas: Android puede retrasarlo
        // unos minutos para ahorrar batería.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        notificationDetails: _details(title, body, image),
        payload: jsonEncode(<String, dynamic>{
          'kind': _payloadKind,
          'route': 'notifications',
          'matchId': match.id,
          'reminder': kind.key,
          'sig': signature,
        }),
      );
    } catch (error) {
      _log('programar recordatorio', error);
    }
  }

  Future<void> _registerReminderInInbox(
    TeamMatchSummary match,
    MatchReminderKind kind,
    String userId,
  ) async {
    final docId = matchNotificationDocId(
      matchId: match.id,
      eventKey: kind.key,
      recipientUserId: userId,
    );

    if (_registeredReminders.contains(docId)) return;

    _registeredReminders.add(docId);

    final reference =
        FirebaseFirestore.instance.collection('notifications').doc(docId);

    try {
      // Si ya está en la bandeja (otro dispositivo o sesión), no se
      // vuelve a crear.
      final existing = await reference.get();

      if (existing.exists) return;
    } catch (_) {
      // Las reglas no permiten leer un documento inexistente ajeno
      // a la consulta; se intenta crear y, si existe, se rechaza.
    }

    final home = await _team(match.homeTeamId);
    final away = await _team(match.awayTeamId);
    final sides = _sides(match, home, away);

    try {
      // Marcar el ID como mostrado para que el listener de la
      // bandeja no lo vuelva a enseñar como notificación del sistema
      // (el recordatorio local ya sonó).
      _seenInbox.add(docId);

      await reference.set(<String, dynamic>{
        'recipientUserId': userId,
        'title': matchupTitle(sides.mine, sides.rival),
        'body': reminderFullBody(
          kind: kind,
          myTeam: sides.mine,
          rival: sides.rival,
          startsAt: match.startsAt!,
          courtName: match.courtName ?? '',
        ),
        'type': 'match_reminder',
        'isRead': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'senderUserId': userId,
        'matchId': match.id,
        'tournamentId': match.tournamentId,
        'route': 'notifications',
        'data': <String, dynamic>{
          'eventKey': kind.key,
          'homeTeamId': match.homeTeamId,
          'awayTeamId': match.awayTeamId,
          'startsAtMillis': match.startsAt!.toUtc().millisecondsSinceEpoch,
          'courtName': match.courtName ?? '',
        },
      });
    } catch (error) {
      // Ya existía o sin conexión: se reintentará en la próxima
      // apertura sin duplicar (mismo ID).
      _registeredReminders.remove(docId);
      _log('registrar recordatorio', error);
    }
  }

  // ==============================================================
  // BANDEJA EN TIEMPO REAL
  // ==============================================================

  void _listenToInbox() {
    _inboxPrimed = false;

    _inboxSubscription = NotificationRepository()
        .watchCurrentUserNotifications(maxItems: 50)
        .listen(
      (notifications) {
        // Primera lectura: lo que ya estaba en la bandeja no se
        // vuelve a mostrar como notificación del sistema.
        if (!_inboxPrimed) {
          _seenInbox.addAll(notifications.map((item) => item.id));
          _inboxPrimed = true;
          return;
        }

        for (final notification in notifications) {
          if (_seenInbox.contains(notification.id)) continue;

          _seenInbox.add(notification.id);

          if (notification.isRead ||
              notification.type == AppNotificationType.matchReminder) {
            continue;
          }

          unawaited(_showInboxNotification(notification));
        }

        // Un cambio de horario reprograma los recordatorios.
        _scheduleSync();
      },
      onError: (Object error) => _log('bandeja', error),
    );
  }

  Future<void> _showInboxNotification(AppNotification notification) async {
    final data = notification.data;
    final homeId = (data['homeTeamId'] as String?) ?? '';
    final awayId = (data['awayTeamId'] as String?) ?? '';

    Uint8List? image;

    if (homeId.isNotEmpty && awayId.isNotEmpty) {
      final home = await _team(homeId);
      final away = await _team(awayId);

      image = await MatchCrestImage.build(
        homeName: home?.displayName ?? 'Local',
        awayName: away?.displayName ?? 'Visitante',
        homeLogoUrl: home?.logoUrl ?? '',
        awayLogoUrl: away?.logoUrl ?? '',
      );
    }

    final startsAtMillis = (data['startsAtMillis'] as num?)?.toInt();
    final String body;

    switch (notification.type) {
      case AppNotificationType.matchCreated:
      case AppNotificationType.matchUpdated:
        body = startsAtMillis == null
            ? notification.body
            : scheduledShortBody(
                rescheduled:
                    notification.type == AppNotificationType.matchUpdated,
                startsAt: DateTime.fromMillisecondsSinceEpoch(
                  startsAtMillis,
                  isUtc: true,
                ),
                courtName: (data['courtName'] as String?) ?? '',
              );
      case AppNotificationType.resultPublished:
        body = 'Resultado final. Toca para ver los detalles.';
      default:
        body = notification.body;
    }

    try {
      await _plugin.show(
        id: stableNotificationId(notification.id),
        title: notification.title,
        body: body,
        notificationDetails: _details(notification.title, body, image),
        payload: jsonEncode(<String, dynamic>{
          'kind': 'canchaya_inbox',
          'route': 'notifications',
          'notificationId': notification.id,
        }),
      );
    } catch (error) {
      _log('mostrar aviso', error);
    }
  }

  // ==============================================================
  // AUXILIARES
  // ==============================================================

  NotificationDetails _details(String title, String body, Uint8List? image) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: image == null ? null : ByteArrayAndroidBitmap(image),
        styleInformation: image == null
            ? BigTextStyleInformation(body)
            : BigPictureStyleInformation(
                ByteArrayAndroidBitmap(image),
                contentTitle: title,
                summaryText: body,
                hideExpandedLargeIcon: true,
              ),
      ),
    );
  }

  Future<PublicTeam?> _team(String teamId) async {
    if (teamId.isEmpty) return null;

    if (_teamCache.containsKey(teamId)) {
      return _teamCache[teamId];
    }

    try {
      final team = await _publicTeams.getTeam(teamId);
      _teamCache[teamId] = team;
      return team;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cancelAllMatchReminders() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();

      for (final request in pending) {
        if (_decode(request.payload)['kind'] == _payloadKind) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (error) {
      _log('cancelar recordatorios', error);
    }
  }

  Map<String, dynamic> _decode(String? payload) {
    if (payload == null || payload.isEmpty) return const {};

    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  void _stopUserListeners() {
    _syncDebounce?.cancel();
    _assignmentSubscription?.cancel();
    _assignmentSubscription = null;
    _inboxSubscription?.cancel();
    _inboxSubscription = null;

    for (final subscription in _matchSubscriptions.values) {
      subscription.cancel();
    }

    _matchSubscriptions.clear();
    _matchesByTeam.clear();
    _myTeamIds.clear();
    _seenInbox.clear();
    _registeredReminders.clear();
    _teamCache.clear();
  }

  void _log(String step, Object error) {
    if (kDebugMode) {
      debugPrint('MatchAlertService ($step): $error');
    }
  }

  Future<void> stop() async {
    _stopUserListeners();
    await _authSubscription?.cancel();
    _authSubscription = null;
    _started = false;
  }
}
