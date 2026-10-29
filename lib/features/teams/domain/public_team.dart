class PublicTeam {
  const PublicTeam({
    required this.id,
    required this.name,
    required this.leagueId,
    required this.tournamentId,
    this.shortName = '',
    this.logoUrl = '',
  });

  final String id;

  /// Nombre oficial completo.
  ///
  /// Ejemplo:
  /// Los Diablos De La Emiliano
  final String name;

  /// Nombre corto elegido por el encargado.
  ///
  /// Ejemplo:
  /// Diablos Emiliano
  ///
  /// Si está vacío, la interfaz puede generar
  /// automáticamente una versión compacta.
  final String shortName;

  /// URL pública del escudo.
  final String logoUrl;

  final String leagueId;

  final String tournamentId;

  // ============================================================
  // HELPERS
  // ============================================================

  bool get hasShortName =>
      shortName.trim().isNotEmpty;

  bool get hasLogo =>
      logoUrl.trim().isNotEmpty;

  /// Nombre preferido para espacios pequeños
  /// como calendario, resultados o clasificación.
  String get displayName {
    final short =
        shortName.trim();

    if (short.isNotEmpty) {
      return short;
    }

    return _compactName(
      name,
    );
  }

  // ============================================================
  // FIRESTORE
  // ============================================================

  factory PublicTeam.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return PublicTeam(
      id: id,
      name:
          _readString(
        data['name'],
      ),
      shortName:
          _readString(
        data['shortName'],
      ),
      logoUrl:
          _readString(
        data['logoUrl'],
      ),
      leagueId:
          _readString(
        data['leagueId'],
      ),
      tournamentId:
          _readString(
        data['tournamentId'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name':
          name.trim(),
      'shortName':
          shortName.trim(),
      'logoUrl':
          logoUrl.trim(),
      'leagueId':
          leagueId.trim(),
      'tournamentId':
          tournamentId.trim(),
    };
  }

  static String _readString(
    dynamic value,
  ) {
    if (value is! String) {
      return '';
    }

    return value.trim();
  }

  // ============================================================
  // NOMBRE COMPACTO AUTOMÁTICO
  // ============================================================

  static String _compactName(
    String value,
  ) {
    final clean =
        value.trim();

    if (clean.isEmpty) {
      return 'Equipo';
    }

    if (clean.length <= 18) {
      return clean;
    }

    const removableWords =
        <String>{
      'el',
      'la',
      'los',
      'las',
      'de',
      'del',
    };

    final words =
        clean
            .split(
              RegExp(
                r'\s+',
              ),
            )
            .where(
              (
                word,
              ) =>
                  !removableWords
                      .contains(
                word.toLowerCase(),
              ),
            )
            .toList();

    final compact =
        words.join(
      ' ',
    );

    if (compact.length <= 20) {
      return compact;
    }

    if (words.length >= 2) {
      final firstAndLast =
          '${words.first} ${words.last}';

      if (firstAndLast.length <= 20) {
        return firstAndLast;
      }
    }

    if (clean.length <= 20) {
      return clean;
    }

    return '${clean.substring(0, 17)}...';
  }
}