import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Durante algunos widget tests Firebase no está inicializado.
    // En ese caso mostramos Inicio normalmente, pero sin consultar Auth.
    if (Firebase.apps.isEmpty) {
      return const _HomeContent(
        user: null,
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return _HomeContent(
          user: user,
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.user,
  });

  final User? user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final displayName = user?.displayName?.trim();

    final name = displayName != null && displayName.isNotEmpty
        ? displayName
        : 'Jugador';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32,
      ),
      children: [
        // Marca principal.
        Row(
          children: [
            Expanded(
              child: Text(
                'CanchaYA',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.primary,
                    ),
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.sports_soccer,
                color: colors.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Saludo.
        Text(
          user != null
              ? 'Bienvenido $name '
              : '',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),

        const SizedBox(height: 5),

        Text(
          user != null
              ? 'Todo tu fútbol en un solo lugar.'
              : 'Organiza equipos, torneos y partidos fácilmente.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),

        const SizedBox(height: 24),

        // Próximo partido.
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary,
                colors.primary.withValues(
                  alpha: 0.78,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: colors.onPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'PRÓXIMO PARTIDO',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                'Aún no tienes partidos programados',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),

              const SizedBox(height: 8),

              Text(
                'Cuando tu equipo tenga un partido programado, aquí aparecerán la fecha, hora, cancha y rival.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimary.withValues(
                        alpha: 0.90,
                      ),
                    ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        Text(
          'Tu actividad',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.groups_outlined,
                value: '0',
                label: 'Equipos',
                backgroundColor: colors.primaryContainer,
                iconColor: colors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                icon: Icons.emoji_events_outlined,
                value: '0',
                label: 'Torneos',
                backgroundColor: colors.secondaryContainer,
                iconColor: colors.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                icon: Icons.sports_soccer_outlined,
                value: '0',
                label: 'Partidos',
                backgroundColor: colors.tertiaryContainer,
                iconColor: colors.tertiary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        Text(
          'CanchaYA',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),

        const SizedBox(height: 12),

        // Equipo
        _InformationCard(
          icon: Icons.groups_2_outlined,
          title: 'Tu equipo',
          description: user == null
              ? 'Inicia sesión para consultar tu equipo.'
              : 'Cuando un encargado te invite a un equipo, podrás aceptar o rechazar la invitación desde tu Perfil.',
        ),

        const SizedBox(height: 10),

        // Torneos
        const _InformationCard(
          icon: Icons.emoji_events_outlined,
          title: 'Torneos',
          description:
              'Consulta competencias, jornadas, resultados y clasificación desde la sección Torneos.',
        ),

        const SizedBox(height: 10),

        // Tabla
        const _InformationCard(
          icon: Icons.table_chart_outlined,
          title: 'Tabla de posiciones',
          description:
              'PJ, PG, PE, PP, GF, GC, DG y puntos estarán disponibles dentro de cada torneo.',
        ),

        const SizedBox(height: 10),

        // Notificaciones
        const _InformationCard(
          icon: Icons.notifications_none_outlined,
          title: 'Recordatorios',
          description:
              'CanchaYA podrá avisarte sobre partidos, cambios de horario, sede y próximos encuentros.',
        ),

        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu temporada empieza aquí',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      user == null
                          ? 'Crea tu cuenta o inicia sesión para comenzar.'
                          : 'No necesitas solicitar acceso a equipos. Cuando un encargado quiera agregarte, recibirás la invitación directamente en tu perfil.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: colors.primary,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}