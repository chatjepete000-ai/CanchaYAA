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
  late final Future<TeamJoinCode> _inviteFuture;

  @override
  void initState() {
    super.initState();
    _inviteFuture = _repository.createJoinCode(widget.team);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitación QR')),
      body: FutureBuilder<TeamJoinCode>(
        future: _inviteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo generar la invitación: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final invite = snapshot.data!;
          final qrValue = 'canchaya://join?code=${invite.code}';

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.team.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'El jugador debe iniciar sesión antes de aceptar esta invitación.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: QrImageView(
                      data: qrValue,
                      size: 230,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Código manual',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SelectableText(
                invite.code,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Válido por 7 días y para un solo uso.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await _repository.cancelJoinCode(invite.code);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invitación cancelada.'),
                      ),
                    );
                    Navigator.of(context).pop();
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No se pudo cancelar: $error',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar invitación'),
              ),
            ],
          );
        },
      ),
    );
  }
}
