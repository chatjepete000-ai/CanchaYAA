import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_card.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Equipos',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 18),
        const EmptyStateCard(
          icon: Icons.groups_outlined,
          title: 'Todavía no hay equipos',
          message: 'La creación de equipos e invitaciones se implementará en F02.',
        ),
      ],
    );
  }
}
