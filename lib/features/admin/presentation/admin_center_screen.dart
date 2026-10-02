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
              icon: Icons.add_business_outlined,
              title: 'Crear liga / organización',
              subtitle:
                  'Crea una organización independiente con su propio administrador, torneos y operación.',
              onTap: () => _createLeague(context),
            ),
            _AdminAction(
              icon: Icons.manage_accounts_outlined,
              title: 'Asignar administrador de liga',
              subtitle:
                  'Da control de una liga específica sin otorgar autoridad global sobre CanchaYA.',
              onTap: () => _assignLeagueAdmin(context),
            ),
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
              title: 'Suspender cuenta global',
              subtitle:
                  'Impide el uso global de CanchaYA. Esta acción nunca está disponible para un administrador de liga.',
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
            _AdminAction(
              icon: Icons.lock_open_outlined,
              title: 'Reactivar cuenta global',
              subtitle:
                  'Devuelve el estado activo a una cuenta previamente suspendida.',
              onTap: () => _promptEmail(
                context,
                title: 'Reactivar cuenta',
                actionLabel: 'Reactivar',
                onSubmit: (email) => AdminRepository().setGlobalAccountStatus(
                  email: email,
                  suspended: false,
                ),
              ),
            ),
          ] else ...[
            _ManagedLeaguesCard(leagueIds: profile.managedLeagueIds),
            const SizedBox(height: 12),
            const _InfoCard(
              icon: Icons.stadium_outlined,
              text:
                  'Desde Torneos puedes crear competencias para tus ligas. Dentro de cada torneo podrás registrar equipos y programar partidos con sede, cancha, zona, árbitro y horario.',
            ),
            const _InfoCard(
              icon: Icons.shield_outlined,
              text:
                  'Puedes retirar equipos o participantes de tus torneos, pero no puedes suspender ni eliminar permanentemente su cuenta de CanchaYA.',
            ),
          ],
          const SizedBox(height: 12),
          const _InfoCard(
            icon: Icons.rule_folder_outlined,
            text:
                'Una baja de torneo o liga es local. La cuenta global sigue existiendo salvo una suspensión realizada por Administración CanchaYA.',
          ),
        ],
      ),
    );
  }

  Future<void> _createLeague(BuildContext context) async {
    final name = TextEditingController();
    final city = TextEditingController();
    final adminEmail = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear liga'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre de liga'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'Ciudad'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: adminEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo del administrador inicial',
                  helperText:
                      'Debe ser una cuenta CanchaYA ya registrada.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty ||
                  adminEmail.text.trim().isEmpty) {
                return;
              }

              try {
                await AdminRepository().createLeague(
                  name: name.text,
                  city: city.text,
                  adminEmail: adminEmail.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Liga creada.')),
                );
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo crear: $error')),
                );
              }
            },
            child: const Text('Crear liga'),
          ),
        ],
      ),
    );

    name.dispose();
    city.dispose();
    adminEmail.dispose();
  }

  Future<void> _assignLeagueAdmin(BuildContext context) async {
    final email = TextEditingController();
    final leagueId = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Asignar administrador de liga'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: leagueId,
                decoration: const InputDecoration(labelText: 'ID de liga'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await AdminRepository().assignLeagueAdminByEmail(
                  email: email.text,
                  leagueId: leagueId.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Administrador de liga asignado.'),
                  ),
                );
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo asignar: $error')),
                );
              }
            },
            child: const Text('Asignar'),
          ),
        ],
      ),
    );

    email.dispose();
    leagueId.dispose();
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
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            platform ? Icons.admin_panel_settings : Icons.stadium_outlined,
            color: colors.onPrimary,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            platform
                ? 'Control global de plataforma'
                : 'Control de tu organización',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            platform
                ? 'Este nivel está por encima de administradores de liga y controla permisos globales.'
                : 'Gestiona únicamente las ligas que te fueron asignadas.',
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagedLeaguesCard extends StatelessWidget {
  const _ManagedLeaguesCard({required this.leagueIds});

  final List<String> leagueIds;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ligas bajo tu administración',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (leagueIds.isEmpty)
              const Text('Todavía no tienes una liga asignada.')
            else
              ...leagueIds.map(
                (id) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.stadium_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(id)),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
