import '../../leagues/domain/league_models.dart';

// ================================================================
// TORNEO PÚBLICO
// ================================================================
//
// publicTournaments/{tournamentId}
//
// Copia de solo lectura de los datos deportivos de
// tournaments/{tournamentId}. La colección privada solo la leen
// los administradores de la liga; esta la puede consultar
// cualquier usuario autenticado desde la sección Torneos.
//
// firestore.rules exige que coincida con tournaments/{id}.
// ================================================================

class PublicTournament {
  const PublicTournament({
    required this.id,
    required this.leagueId,
    required this.name,
    required this.category,
    required this.city,
    required this.format,
    required this.status,
    this.season = '',
  });

  final String id;
  final String leagueId;
  final String name;
  final String category;
  final String city;
  final String season;
  final TournamentFormat format;
  final TournamentStatus status;

  /// Los torneos cancelados no se muestran en la sección pública.
  bool get isPubliclyListed =>
      status != TournamentStatus.cancelled;

  factory PublicTournament.fromTournament(
    Tournament tournament,
  ) {
    return PublicTournament(
      id: tournament.id,
      leagueId: tournament.leagueId,
      name: tournament.name,
      category: tournament.category,
      city: tournament.city,
      season: tournament.season,
      format: tournament.format,
      status: tournament.status,
    );
  }

  factory PublicTournament.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return PublicTournament(
      id: id,
      leagueId: (data['leagueId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      season: (data['season'] as String?) ?? '',
      format: TournamentFormatX.fromValue(
        data['format'] as String?,
      ),
      status: TournamentStatusX.fromValue(
        data['status'] as String?,
      ),
    );
  }

  /// Datos exactos que se guardan (sin updatedAt).
  ///
  /// Deben coincidir campo por campo con tournaments/{id}; por eso
  /// no se recortan espacios aquí (el torneo ya se guardó limpio).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'leagueId': leagueId,
      'name': name,
      'category': category,
      'city': city,
      'season': season,
      'format': format.value,
      'status': status.value,
    };
  }

  bool sameDataAs(
    PublicTournament other,
  ) {
    return leagueId == other.leagueId &&
        name == other.name &&
        category == other.category &&
        city == other.city &&
        season == other.season &&
        format == other.format &&
        status == other.status;
  }
}
