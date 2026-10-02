class TournamentSummary {
  const TournamentSummary({
    required this.id,
    required this.name,
    required this.leagueId,
    required this.category,
    required this.city,
    required this.status,
  });

  final String id;
  final String name;
  final String leagueId;
  final String category;
  final String city;
  final String status;

  factory TournamentSummary.fromMap(String id, Map<String, dynamic> data) {
    return TournamentSummary(
      id: id,
      name: (data['name'] as String?) ?? 'Torneo',
      leagueId: (data['leagueId'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'draft',
    );
  }
}
