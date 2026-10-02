import 'package:flutter/material.dart';

import '../../auth/domain/user_role.dart';
import '../../profile/domain/user_profile.dart';
import '../data/admin_repository.dart';

class AdminCenterScreen extends StatelessWidget {
  const AdminCenterScreen({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final platform = profile.adminScope == AdminScope.platform;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          platform ? 'Administración CanchaYA' : 'Administración de liga',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeroCard(platform: platform),
          const SizedBox(height: 20),
          if (platform) ...[
            _AdminAction(
              icon: Icons.groups_3_outlined,
              title: 'Dar permiso de encargado',
              subtitle:
                  'Convierte un jugador en Capitán / Encargado para que pueda crear y administrar equipos.',
              onTap: () => _promptEmail(
                context,
                title: 'Dar permiso de encargado',
                actionLabel: 'Asignar',
                onSubmit: (email) =>
                    AdminRepository().promoteCaptainByEmail(email),
              ),
            ),
            _AdminAction(
              icon: Icons.block_outlined,
              title: 'Suspensión global de cuenta',
              subtitle:
                  'Solo administración de plataforma puede suspender una cuenta de toda CanchaYA.',
              onTap: () => _promptEmail(
                context,
                title: 'Suspender cuenta global',
                actionLabel: 'Suspender',
                onSubmit: (email) => AdminRepository().setGlobalAccountStatus(
                  email: email,
                  suspended: true,
                ),
              ),
            ),
          ] else ...[
            const _InfoCard(
              icon: Icons.shield_outlined,
              text:
                  'Puedes administrar tus ligas y torneos, pero no puedes suspender ni eliminar permanentemente cuentas de CanchaYA.',
            ),
          ],
          const SizedBox(height: 12),
          const _InfoCard(
            icon: Icons.rule_folder_outlined,
            text:
                'Eliminar a un jugador o equipo de una liga o torneo es una acción local. La cuenta global permanece activa salvo que Administración CanchaYA la suspenda.',
          ),
        ],
      ),
    );
  }

  Future<void> _promptEmail(
    BuildContext context, {
    required String title,
    required String actionLabel,
    required Future<void> Function(String email) onSubmit,
  }) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo del usuario'),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await onSubmit(controller.text);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cambio aplicado correctamente.'),
                            ),
                          );
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setState(() => busy = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$error')),
                          );
                        }
                      },
                child: Text(actionLabel),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.platform});

  final bool platform;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            platform ? Icons.admin_panel_settings : Icons.stadium_outlined,
            color: colors.primary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            platform
                ? 'Control global de plataforma'
                : 'Control de tu organización',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            platform
                ? 'Este nivel está por encima de administradores de liga y puede administrar cuentas y permisos globales.'
                : 'Gestiona torneos, equipos inscritos, campos, horarios, zonas, árbitros y resultados dentro de tus ligas.',
          ),
        ],
      ),
    );
  }
}

class _AdminAction extends StatelessWidget {
  const _AdminAction({
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
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
