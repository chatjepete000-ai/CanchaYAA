import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/team_repository.dart';
import '../domain/team_models.dart';

class TeamInviteQrScreen extends StatefulWidget {
  const TeamInviteQrScreen({
    super.key,
    required this.team,
  });

  final TeamSummary team;

  @override
  State<TeamInviteQrScreen> createState() => _TeamInviteQrScreenState();
}

class _TeamInviteQrScreenState extends State<TeamInviteQrScreen> {
  final _repository = TeamRepository();
  bool _creating = false;

  Future<void> _createInvite() async {
    if (_creating) return;

    setState(() => _creating = true);
    try {
      final invite = await _repository.createJoinCode(widget.team);
      if (!mounted) return;
      await _showInvite(invite);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar: ' + error.toString())),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _showInvite(TeamJoinCode invite) async {
    final qrValue = 'canchaya://join?code=' + invite.code;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.team.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: qrValue,
                size: 220,
              ),
              const SizedBox(height: 16),
              const Text(
                'Código manual',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SelectableText(
                invite.code,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La invitación es de un solo uso y vence automáticamente.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelInvite(TeamJoinCode invite) async {
    try {
      await _repository.cancelJoinCode(invite.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación cancelada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: ' + error.toString())),
      );
    }
  }

  String _expiryLabel(TeamJoinCode invite) {
    final expires = invite.expiresAt;
    if (expires == null) return 'Invitación activa';

    final day = expires.day.toString().padLeft(2, '0');
    final month = expires.month.toString().padLeft(2, '0');
    return 'Vence: ' + day + '/' + month + '/' + expires.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Invitaciones QR')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createInvite,
        icon: _creating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_2),
        label: Text(_creating ? 'Generando...' : 'Nueva invitación'),
      ),
      body: StreamBuilder<List<TeamJoinCode>>(
        stream: _repository.watchActiveJoinCodes(widget.team.id),
        builder: (context, snapshot) {
          final invites = snapshot.data ?? const [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: colors.onPrimary,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.team.name,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Genera códigos controlados para jugadores invitados. Puedes cancelarlos mientras sigan activos.',
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Invitaciones activas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No se pudieron cargar las invitaciones activas.',
                    ),
                  ),
                )
              else if (invites.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_2),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No hay códigos activos. Crea uno cuando necesites invitar a un jugador.',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...invites.map(
                  (invite) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_2),
                        title: Text(
                          invite.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        subtitle: Text(_expiryLabel(invite)),
                        onTap: () => _showInvite(invite),
                        trailing: IconButton(
                          tooltip: 'Cancelar invitación',
                          onPressed: () => _cancelInvite(invite),
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Si la cámara del jugador no está disponible, puede escribir manualmente el mismo código desde su Perfil.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
