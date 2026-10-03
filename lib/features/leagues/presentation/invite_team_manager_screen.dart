import 'package:flutter/material.dart';

import '../../teams/data/team_repository.dart';
import '../../teams/domain/team_models.dart';

class InviteTeamManagerScreen extends StatefulWidget {
  const InviteTeamManagerScreen({
    super.key,
    required this.team,
  });

  final Team team;

  @override
  State<InviteTeamManagerScreen> createState() =>
      _InviteTeamManagerScreenState();
}

class _InviteTeamManagerScreenState
    extends State<InviteTeamManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  final TeamRepository _teamRepository = TeamRepository();

  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _teamRepository.sendManagerInvitation(
        teamId: widget.team.id,
        teamName: widget.team.name,
        leagueId: widget.team.leagueId,
        tournamentId: widget.team.tournamentId,
        invitedEmail: _emailController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invitación enviada correctamente.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar la invitación: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim().toLowerCase() ?? '';

    if (email.isEmpty) {
      return 'Escribe el correo del usuario.';
    }

    final emailExpression = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailExpression.hasMatch(email)) {
      return 'Escribe un correo electrónico válido.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Invitar encargado',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
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
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: colors.onPrimary.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.manage_accounts_outlined,
                            color: colors.onPrimary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.team.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: colors.onPrimary,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Asignar encargado temporal',
                                style: TextStyle(
                                  color:
                                      colors.onPrimary.withValues(
                                    alpha: 0.88,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'La persona recibirá una invitación para administrar este equipo durante el torneo.',
                      style: TextStyle(
                        color: colors.onPrimary.withValues(
                          alpha: 0.92,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              Text(
                'Correo del usuario',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),

              const SizedBox(height: 8),

              Text(
                'Escribe el mismo correo con el que la persona está registrada en CanchaYA.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                autofillHints: const [
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'usuario@correo.com',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                  ),
                ),
                validator: _validateEmail,
                onFieldSubmitted: (_) {
                  if (!_sending) {
                    _sendInvitation();
                  }
                },
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed:
                    _sending ? null : _sendInvitation,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_outlined,
                      ),
                label: Text(
                  _sending
                      ? 'Enviando...'
                      : 'Enviar invitación',
                ),
              ),

              const SizedBox(height: 26),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security_outlined,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '¿Qué pasará después?',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. El usuario recibirá la invitación dentro de CanchaYA.',
                    ),
                    SizedBox(height: 7),
                    Text(
                      '2. Podrá aceptarla o rechazarla.',
                    ),
                    SizedBox(height: 7),
                    Text(
                      '3. Si acepta, obtendrá permisos temporales sobre este equipo.',
                    ),
                    SizedBox(height: 7),
                    Text(
                      '4. Podrá administrar plantilla, jugadores, escudo, uniforme y otras funciones del equipo.',
                    ),
                    SizedBox(height: 7),
                    Text(
                      '5. Cuando termine el torneo o se revoque su cargo, perderá esos permisos pero se conservará su historial.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ser encargado de equipo no convierte al usuario en administrador de liga ni en administrador de plataforma. Sus permisos quedan limitados al equipo y al torneo correspondientes.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}