import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

const Color _notificationGreen = Color(0xFF0E9F57);
const double _notificationMaxWidth = 720;

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({
    super.key,
  });

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends State<NotificationCenterScreen> {
  final NotificationRepository _repository =
      NotificationRepository();

  bool _markingAll = false;

  Stream<List<AppNotification>> _watchNotifications() {
    try {
      return _repository.watchCurrentUserNotifications(
        maxItems: 100,
      );
    } catch (error) {
      return Stream<List<AppNotification>>.error(
        error,
      );
    }
  }

  Stream<int> _watchUnreadCount() {
    try {
      return _repository.watchUnreadCount();
    } catch (error) {
      return Stream<int>.error(
        error,
      );
    }
  }

  Future<void> _markAllAsRead() async {
    if (_markingAll) {
      return;
    }

    setState(() {
      _markingAll = true;
    });

    try {
      final updated =
          await _repository.markAllAsRead();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated == 0
                ? 'No tienes notificaciones pendientes.'
                : updated == 1
                    ? '1 notificación marcada como leída.'
                    : '$updated notificaciones marcadas como leídas.',
          ),
        ),
      );
    } on NotificationRepositoryException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        'No se pudieron actualizar tus notificaciones.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _markingAll = false;
        });
      }
    }
  }

  Future<void> _openNotification(
    AppNotification notification,
  ) async {
    if (notification.unread) {
      try {
        await _repository.markAsRead(
          notification.id,
        );
      } on NotificationRepositoryException catch (error) {
        if (!mounted) {
          return;
        }

        _showError(
          error.message,
        );

        return;
      } catch (_) {
        if (!mounted) {
          return;
        }

        _showError(
          'No se pudo actualizar la notificación.',
        );

        return;
      }
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _NotificationDetailsSheet(
          notification: notification,
        );
      },
    );
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notificaciones',
        ),
        actions: [
          StreamBuilder<int>(
            stream: _watchUnreadCount(),
            builder: (
              context,
              snapshot,
            ) {
              final unread =
                  snapshot.data ?? 0;

              if (unread <= 0 &&
                  !_markingAll) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(
                  right: 6,
                ),
                child: TextButton.icon(
                  onPressed:
                      _markingAll || unread <= 0
                          ? null
                          : _markAllAsRead,
                  icon: _markingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          CupertinoIcons
                              .check_mark_circled,
                          size: 18,
                        ),
                  label: const Text(
                    'Marcar todo',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final width =
              constraints.maxWidth >
                      _notificationMaxWidth
                  ? _notificationMaxWidth
                  : constraints.maxWidth;

          final horizontalPadding =
              constraints.maxWidth < 380
                  ? 12.0
                  : constraints.maxWidth < 600
                      ? 16.0
                      : 22.0;

          return Center(
            child: SizedBox(
              width: width,
              child:
                  StreamBuilder<List<AppNotification>>(
                stream: _watchNotifications(),
                builder: (
                  context,
                  snapshot,
                ) {
                  if (snapshot.connectionState ==
                          ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return _NotificationErrorState(
                      message:
                          _readableError(
                        snapshot.error,
                      ),
                    );
                  }

                  final notifications =
                      snapshot.data ??
                          const <AppNotification>[];

                  if (notifications.isEmpty) {
                    return const _EmptyNotificationsState();
                  }

                  final groups =
                      _groupNotifications(
                    notifications,
                  );

                  return ListView(
                    physics:
                        const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      14,
                      horizontalPadding,
                      36,
                    ),
                    children: [
                      _NotificationSummaryCard(
                        notifications:
                            notifications,
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      for (final group
                          in groups) ...[
                        _NotificationGroupTitle(
                          title:
                              group.title,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        _NotificationGroupCard(
                          notifications:
                              group.notifications,
                          onTap:
                              _openNotification,
                        ),

                        const SizedBox(
                          height: 24,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _readableError(
    Object? error,
  ) {
    if (error is NotificationRepositoryException) {
      return error.message;
    }

    return 'No se pudieron cargar tus notificaciones.';
  }

  List<_NotificationGroup> _groupNotifications(
    List<AppNotification> notifications,
  ) {
    final today =
        <AppNotification>[];

    final yesterday =
        <AppNotification>[];

    final older =
        <AppNotification>[];

    final now =
        DateTime.now();

    final startToday =
        DateTime(
      now.year,
      now.month,
      now.day,
    );

    final startYesterday =
        startToday.subtract(
      const Duration(
        days: 1,
      ),
    );

    for (final notification
        in notifications) {
      final created =
          notification.createdAt;

      if (!created.isBefore(
        startToday,
      )) {
        today.add(
          notification,
        );

        continue;
      }

      if (!created.isBefore(
        startYesterday,
      )) {
        yesterday.add(
          notification,
        );

        continue;
      }

      older.add(
        notification,
      );
    }

    final result =
        <_NotificationGroup>[];

    if (today.isNotEmpty) {
      result.add(
        _NotificationGroup(
          title: 'HOY',
          notifications:
              today,
        ),
      );
    }

    if (yesterday.isNotEmpty) {
      result.add(
        _NotificationGroup(
          title: 'AYER',
          notifications:
              yesterday,
        ),
      );
    }

    if (older.isNotEmpty) {
      result.add(
        _NotificationGroup(
          title: 'ANTERIORES',
          notifications:
              older,
        ),
      );
    }

    return result;
  }
}

class _NotificationSummaryCard
    extends StatelessWidget {
  const _NotificationSummaryCard({
    required this.notifications,
  });

  final List<AppNotification>
      notifications;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final unread =
        notifications.where(
      (notification) =>
          notification.unread,
    ).length;

    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color:
              colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color: _notificationGreen
                  .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Stack(
              clipBehavior:
                  Clip.none,
              children: [
                const Center(
                  child: Icon(
                    CupertinoIcons
                        .bell_fill,
                    color:
                        _notificationGreen,
                    size: 24,
                  ),
                ),

                if (unread > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child:
                        Container(
                      constraints:
                          const BoxConstraints(
                        minWidth:
                            18,
                        minHeight:
                            18,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            4,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.red,
                        borderRadius:
                            BorderRadius
                                .circular(
                          100,
                        ),
                      ),
                      alignment:
                          Alignment
                              .center,
                      child: Text(
                        unread > 99
                            ? '99+'
                            : unread
                                .toString(),
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              9,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  unread == 0
                      ? 'Todo al día'
                      : unread == 1
                          ? 'Tienes 1 notificación nueva'
                          : 'Tienes $unread notificaciones nuevas',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  unread == 0
                      ? 'No tienes avisos pendientes.'
                      : 'Revisa la actividad reciente de tu cuenta.',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationGroupTitle
    extends StatelessWidget {
  const _NotificationGroupTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration:
              BoxDecoration(
            color:
                _notificationGreen,
            borderRadius:
                BorderRadius.circular(
              2,
            ),
          ),
        ),

        const SizedBox(
          width: 9,
        ),

        Text(
          title,
          style: TextStyle(
            color: colors
                .onSurfaceVariant,
            fontSize: 11.5,
            fontWeight:
                FontWeight.w900,
            letterSpacing:
                1.20,
          ),
        ),
      ],
    );
  }
}

class _NotificationGroupCard
    extends StatelessWidget {
  const _NotificationGroupCard({
    required this.notifications,
    required this.onTap,
  });

  final List<AppNotification>
      notifications;

  final Future<void> Function(
    AppNotification notification,
  ) onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              colors.outlineVariant,
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0;
              index <
                  notifications.length;
              index++) ...[
            _NotificationRow(
              notification:
                  notifications[index],
              onTap: () {
                onTap(
                  notifications[index],
                );
              },
            ),

            if (index !=
                notifications.length - 1)
              Divider(
                height: 1,
                indent: 68,
                color: colors
                    .outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _NotificationRow
    extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
  });

  final AppNotification
      notification;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final unread =
        notification.unread;

    return Material(
      color: unread
          ? _notificationGreen
              .withValues(
              alpha: 0.045,
            )
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior:
                    Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color:
                          _notificationGreen
                              .withValues(
                        alpha:
                            unread
                                ? 0.14
                                : 0.08,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        13,
                      ),
                    ),
                    child: Icon(
                      _iconForType(
                        notification.type,
                      ),
                      color:
                          _notificationGreen,
                      size: 20,
                    ),
                  ),

                  if (unread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child:
                          Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(
                          color:
                              _notificationGreen,
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color: colors
                                .surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification
                                    .title
                                    .trim()
                                    .isEmpty
                                ? notification
                                    .type
                                    .label
                                : notification
                                    .title,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: theme
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontWeight:
                                      unread
                                          ? FontWeight
                                              .w900
                                          : FontWeight
                                              .w700,
                                ),
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Text(
                          _relativeTime(
                            notification
                                .createdAt,
                          ),
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: colors
                                    .onSurfaceVariant,
                                fontSize:
                                    10.5,
                              ),
                        ),
                      ],
                    ),

                    if (notification
                        .body
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow:
                            TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: colors
                                  .onSurfaceVariant,
                              height:
                                  1.3,
                            ),
                      ),
                    ],

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      notification
                          .type.label,
                      style:
                          const TextStyle(
                        color:
                            _notificationGreen,
                        fontSize:
                            10.5,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 6,
              ),

              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 12,
                ),
                child: Icon(
                  CupertinoIcons
                      .chevron_right,
                  size: 15,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(
    AppNotificationType type,
  ) {
    switch (type) {
      case AppNotificationType.teamInvitation:
        return CupertinoIcons
            .person_add_solid;

      case AppNotificationType.invitationAccepted:
        return CupertinoIcons
            .check_mark_circled_solid;

      case AppNotificationType.invitationRejected:
        return CupertinoIcons
            .xmark_circle_fill;

      case AppNotificationType.teamUpdate:
        return CupertinoIcons
            .person_2_fill;

      case AppNotificationType.matchCreated:
        return CupertinoIcons
            .sportscourt_fill;

      case AppNotificationType.matchUpdated:
        return CupertinoIcons
            .arrow_2_circlepath;

      case AppNotificationType.matchReminder:
        return CupertinoIcons
            .clock_fill;

      case AppNotificationType.tournamentUpdate:
        return CupertinoIcons
            .star_fill;

      case AppNotificationType.resultPublished:
        return CupertinoIcons
            .flag_fill;

      case AppNotificationType.system:
        return CupertinoIcons
            .bell_fill;
    }
  }

  String _relativeTime(
    DateTime createdAt,
  ) {
    final now =
        DateTime.now();

    final difference =
        now.difference(
      createdAt,
    );

    if (difference.isNegative) {
      return 'Ahora';
    }

    if (difference.inMinutes <
        1) {
      return 'Ahora';
    }

    if (difference.inMinutes <
        60) {
      return '${difference.inMinutes} min';
    }

    if (difference.inHours <
        24) {
      return '${difference.inHours} h';
    }

    if (difference.inDays ==
        1) {
      return 'Ayer';
    }

    if (difference.inDays <
        7) {
      return '${difference.inDays} d';
    }

    return '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year}';
  }
}

class _NotificationDetailsSheet
    extends StatelessWidget {
  const _NotificationDetailsSheet({
    required this.notification,
  });

  final AppNotification
      notification;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(
          top: Radius.circular(
            28,
          ),
        ),
      ),
      padding:
          const EdgeInsets.fromLTRB(
        18,
        10,
        18,
        28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration:
                    BoxDecoration(
                  color: colors
                      .onSurfaceVariant
                      .withValues(
                    alpha: 0.28,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    100,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(
                    color:
                        _notificationGreen
                            .withValues(
                      alpha: 0.11,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    _detailsIcon(
                      notification.type,
                    ),
                    color:
                        _notificationGreen,
                    size: 22,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Text(
                    notification
                            .title
                            .trim()
                            .isEmpty
                        ? notification
                            .type.label
                        : notification
                            .title,
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                  ),
                ),

                IconButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pop();
                  },
                  icon: const Icon(
                    CupertinoIcons
                        .xmark,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

            if (notification
                .body
                .trim()
                .isNotEmpty)
              Text(
                notification.body,
                style: theme
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                      height: 1.45,
                    ),
              ),

            const SizedBox(
              height: 22,
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                14,
              ),
              decoration:
                  BoxDecoration(
                color: colors
                    .surfaceContainerHighest
                    .withValues(
                  alpha: 0.45,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons
                        .clock,
                    size: 18,
                    color:
                        _notificationGreen,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Text(
                      _formatFullDate(
                        notification
                            .createdAt,
                      ),
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: colors
                                .onSurfaceVariant,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _detailsIcon(
    AppNotificationType type,
  ) {
    switch (type) {
      case AppNotificationType.teamInvitation:
        return CupertinoIcons
            .person_add_solid;

      case AppNotificationType.invitationAccepted:
        return CupertinoIcons
            .check_mark_circled_solid;

      case AppNotificationType.invitationRejected:
        return CupertinoIcons
            .xmark_circle_fill;

      case AppNotificationType.teamUpdate:
        return CupertinoIcons
            .person_2_fill;

      case AppNotificationType.matchCreated:
        return CupertinoIcons
            .sportscourt_fill;

      case AppNotificationType.matchUpdated:
        return CupertinoIcons
            .arrow_2_circlepath;

      case AppNotificationType.matchReminder:
        return CupertinoIcons
            .clock_fill;

      case AppNotificationType.tournamentUpdate:
        return CupertinoIcons
            .star_fill;

      case AppNotificationType.resultPublished:
        return CupertinoIcons
            .flag_fill;

      case AppNotificationType.system:
        return CupertinoIcons
            .bell_fill;
    }
  }

  String _formatFullDate(
    DateTime date,
  ) {
    const months =
        <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    final hour =
        date.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '${date.day} de ${months[date.month - 1]} de ${date.year} · '
        '$hour:$minute';
  }
}

class _EmptyNotificationsState
    extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 420,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(
            28,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration:
                    BoxDecoration(
                  color:
                      _notificationGreen
                          .withValues(
                    alpha: 0.10,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons
                      .bell,
                  color:
                      _notificationGreen,
                  size: 34,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                'Sin notificaciones',
                textAlign:
                    TextAlign.center,
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'Aquí aparecerán invitaciones, partidos, torneos y avisos importantes de CanchaYA.',
                textAlign:
                    TextAlign.center,
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationErrorState
    extends StatelessWidget {
  const _NotificationErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 460,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),
          child: Container(
            padding:
                const EdgeInsets.all(
              18,
            ),
            decoration:
                BoxDecoration(
              color: colors.surface,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              border: Border.all(
                color: colors
                    .outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons
                      .exclamationmark_triangle,
                  size: 32,
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  'No pudimos cargar tus notificaciones',
                  textAlign:
                      TextAlign.center,
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  message,
                  textAlign:
                      TextAlign.center,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationGroup {
  const _NotificationGroup({
    required this.title,
    required this.notifications,
  });

  final String title;

  final List<AppNotification>
      notifications;
}