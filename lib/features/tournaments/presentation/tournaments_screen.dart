import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_card.dart';

class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Torneos',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 18),
        const EmptyStateCard(
          icon: Icons.emoji_events_outlined,
          title: 'Sin torneos registrados',
          message: 'Aquí aparecerán calendario, resultados y posiciones de F05 y F08.',
        ),
      ],
    );
  }
}
