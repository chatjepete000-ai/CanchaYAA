class Court {
  const Court({
    required this.id,
    required this.name,
    required this.address,
    this.city = 'Montemorelos',
    this.sport = 'Fútbol 7',
    this.latitude,
    this.longitude,
    this.createdBy = '',
    this.active = true,
  });
  final String id, name, address, city, sport, createdBy;
  final double? latitude, longitude;
  final bool active;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

  Uri get directionsUri => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': hasCoordinates
        ? '$latitude,$longitude'
        : '$name, $address, $city, Nuevo León, México',
  });

  factory Court.fromMap(String id, Map<String, dynamic> data) => Court(
    id: id,
    name: data['name'] as String? ?? '',
    address: data['address'] as String? ?? '',
    city: data['city'] as String? ?? '',
    sport: data['sport'] as String? ?? 'Fútbol 7',
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
    createdBy: data['createdBy'] as String? ?? '',
    active: data['active'] != false,
  );

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'address': address.trim(),
    'city': city.trim(),
    'sport': sport,
    'latitude': latitude,
    'longitude': longitude,
    'active': active,
  };
}

// Source: municipal sports directory. Coordinates intentionally omitted until
// an administrator verifies the actual pitch (a complex may have several).
const montemorelosCourts = [
  // OSM node 5348015110: sports-complex location, not a specific playing field.
  Court(
    id: 'montemorelos-almazan',
    name: 'Polideportivo Almazán',
    address: 'Calle Zacatecas con Carlos Cantú',
    sport: 'Usos múltiples',
    latitude: 25.188009,
    longitude: -99.8325685,
  ),
  Court(
    id: 'montemorelos-pavorreales',
    name: 'Unidad Deportiva Pavorreales',
    address: 'Av. Libertad entre Camino al Vapor y Pilón Viejo',
    sport: 'Fútbol 11',
  ),
  Court(
    id: 'montemorelos-oriente',
    name: 'Unidad Deportiva Oriente',
    address: 'Av. Fidel Velázquez s/n',
    sport: 'Fútbol 11',
  ),
  Court(
    id: 'montemorelos-sabinos',
    name: 'Cancha Los Sabinos',
    address: 'Av. Bugambilias s/n',
  ),
  Court(
    id: 'montemorelos-infonavit',
    name: 'Cancha Infonavit',
    address: 'Av. Fidel Velázquez y Raúl Rangel Frías',
  ),
];
