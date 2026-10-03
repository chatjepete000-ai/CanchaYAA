enum LeagueStatus {
  active,
  inactive,
  finished,
}

extension LeagueStatusX on LeagueStatus {
  String get value => name;

  String get label {
    switch (this) {
      case LeagueStatus.active:
        return 'Activa';
      case LeagueStatus.inactive:
        return 'Inactiva';
      case LeagueStatus.finished:
        return 'Finalizada';
    }
  }

  static LeagueStatus fromValue(String? value) {
    return LeagueStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => LeagueStatus.active,
    );
  }
}

enum TournamentStatus {
  draft,
  registration,
  active,
  finished,
  cancelled,
}

extension TournamentStatusX on TournamentStatus {
  String get value => name;

  String get label {
    switch (this) {
      case TournamentStatus.draft:
        return 'Borrador';
      case TournamentStatus.registration:
        return 'Inscripciones';
      case TournamentStatus.active:
        return 'En curso';
      case TournamentStatus.finished:
        return 'Finalizado';
      case TournamentStatus.cancelled:
        return 'Cancelado';
    }
  }

  static TournamentStatus fromValue(String? value) {
    return TournamentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TournamentStatus.draft,
    );
  }
}

enum TournamentFormat {
  football5,
  football7,
  football11,
}

extension TournamentFormatX on TournamentFormat {
  String get value => name;

  String get label {
    switch (this) {
      case TournamentFormat.football5:
        return 'Fútbol 5';
      case TournamentFormat.football7:
        return 'Fútbol 7';
      case TournamentFormat.football11:
        return 'Fútbol 11';
    }
  }

  static TournamentFormat fromValue(String? value) {
    return TournamentFormat.values.firstWhere(
      (format) => format.name == value,
      orElse: () => TournamentFormat.football7,
    );
  }
}

class League {
  const League({
    required this.id,
    required this.name,
    required this.organizationName,
    required this.city,
    required this.status,
    this.adminUserIds = const [],
    this.description = '',
  });

  final String id;
  final String name;
  final String organizationName;
  final String city;
  final String description;
  final LeagueStatus status;
  final List<String> adminUserIds;

  bool isAdmin(String userId) {
    return adminUserIds.contains(userId);
  }

  factory League.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return League(
      id: id,
      name: (data['name'] as String?)?.trim() ?? '',
      organizationName:
          (data['organizationName'] as String?)?.trim() ?? '',
      city: (data['city'] as String?)?.trim() ?? '',
      description:
          (data['description'] as String?)?.trim() ?? '',
      status: LeagueStatusX.fromValue(
        data['status'] as String?,
      ),
      adminUserIds: List<String>.from(
        (data['adminUserIds'] as List<dynamic>?) ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'organizationName': organizationName.trim(),
      'city': city.trim(),
      'description': description.trim(),
      'status': status.value,
      'adminUserIds': adminUserIds,
    };
  }
}

class Tournament {
  const Tournament({
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

  factory Tournament.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return Tournament(
      id: id,
      leagueId: (data['leagueId'] as String?)?.trim() ?? '',
      name: (data['name'] as String?)?.trim() ?? '',
      category: (data['category'] as String?)?.trim() ?? '',
      city: (data['city'] as String?)?.trim() ?? '',
      season: (data['season'] as String?)?.trim() ?? '',
      format: TournamentFormatX.fromValue(
        data['format'] as String?,
      ),
      status: TournamentStatusX.fromValue(
        data['status'] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leagueId': leagueId,
      'name': name.trim(),
      'category': category.trim(),
      'city': city.trim(),
      'season': season.trim(),
      'format': format.value,
      'status': status.value,
    };
  }
}