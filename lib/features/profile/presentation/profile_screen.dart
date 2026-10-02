import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Perfil',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 18),
        const EmptyStateCard(
          icon: Icons.person_outline,
          title: 'Perfil de jugador',
          message: 'El registro seguro, la foto y la unión a equipos se completarán en F01 y F03.',
        ),
      ],
    );
  }
}
