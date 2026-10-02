import 'package:flutter/material.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          'CanchaYA',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tu liga, tus equipos y tus partidos en un solo lugar.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.primaryContainer,
                      child: Icon(Icons.sports_soccer, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Base inicial lista',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Esta versión prepara la navegación y la estructura para equipos, torneos, perfiles y futuras conexiones seguras a la nube.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Accesos rápidos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        _QuickAction(
          icon: Icons.calendar_month,
          title: 'Próximos partidos',
          subtitle: 'Consulta fecha, hora, sede y cancha.',
          onTap: () {},
        ),
        const SizedBox(height: 10),
        _QuickAction(
          icon: Icons.table_chart_outlined,
          title: 'Tabla de posiciones',
          subtitle: 'Puntos, partidos, victorias, empates y derrotas.',
          onTap: () {},
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
