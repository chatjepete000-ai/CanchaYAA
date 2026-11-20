import 'package:latlong2/latlong.dart';

// ================================================================
// CIUDAD / MUNICIPIO DEL USUARIO
// ================================================================
//
// Se guarda en users/{uid}.preferredLocation:
//
//   city       'Linares'
//   state      'Nuevo León'
//   latitude   24.86   (opcional)
//   longitude  -99.56  (opcional)
//
// No se usa el GPS del teléfono: el usuario elige su ciudad. Las
// coordenadas vienen de OpenStreetMap (búsqueda) o de las canchas
// registradas en esa ciudad; nunca se inventan. Si no hay
// coordenadas, la ciudad sigue funcionando para filtrar por nombre.
// ================================================================

class UserLocation {
  const UserLocation({
    required this.city,
    required this.state,
    this.latitude,
    this.longitude,
  });

  /// Ciudad inicial del proyecto (coordenadas que ya usa el mapa).
  static const UserLocation montemorelos = UserLocation(
    city: 'Montemorelos',
    state: 'Nuevo León',
    latitude: 25.187,
    longitude: -99.828,
  );

  static const int maxTextLength = 100;

  final String city;
  final String state;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

  LatLng? get point => hasCoordinates ? LatLng(latitude!, longitude!) : null;

  /// "Montemorelos, N.L."
  String get label {
    final abbreviation = stateAbbreviation(state);

    if (abbreviation.isEmpty) {
      return city;
    }

    return '$city, $abbreviation';
  }

  /// true si [otherCity] es la misma ciudad (sin acentos ni mayúsculas).
  ///
  /// También acepta el nombre corto o el largo de la misma ciudad:
  /// "Cadereyta" y "Cadereyta Jiménez", "Santiago" y "Santiago, N.L.".
  bool matchesCity(String otherCity) {
    final a = normalizePlaceName(otherCity).replaceAll(',', ' ').trim();
    final b = normalizePlaceName(city).replaceAll(',', ' ').trim();

    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;

    final shorter = a.length < b.length ? a : b;
    final longer = a.length < b.length ? b : a;

    // Solo palabras completas al inicio ("san" no coincide con
    // "san nicolas", porque son 3 letras).
    return shorter.length >= 4 && longer.startsWith('$shorter ');
  }

  /// Distancia en kilómetros a un punto, o null sin coordenadas.
  double? distanceKmTo(double? latitude, double? longitude) {
    final origin = point;

    if (origin == null || latitude == null || longitude == null) {
      return null;
    }

    return const Distance().as(
          LengthUnit.Meter,
          origin,
          LatLng(latitude, longitude),
        ) /
        1000;
  }

  factory UserLocation.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return montemorelos;
    }

    final city = (data['city'] as String?)?.trim() ?? '';

    if (city.isEmpty) {
      return montemorelos;
    }

    return UserLocation(
      city: city,
      state: (data['state'] as String?)?.trim() ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'city': _limit(city),
      'state': _limit(state),
      'latitude': hasCoordinates ? latitude : null,
      'longitude': hasCoordinates ? longitude : null,
    };
  }

  static String _limit(String value) {
    final clean = value.trim();
    return clean.length <= maxTextLength
        ? clean
        : clean.substring(0, maxTextLength);
  }

  @override
  bool operator ==(Object other) =>
      other is UserLocation &&
      normalizePlaceName(other.city) == normalizePlaceName(city) &&
      normalizePlaceName(other.state) == normalizePlaceName(state);

  @override
  int get hashCode =>
      Object.hash(normalizePlaceName(city), normalizePlaceName(state));
}

/// Minúsculas, sin acentos y sin espacios repetidos.
String normalizePlaceName(String value) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  final lower = value.trim().toLowerCase();
  final buffer = StringBuffer();

  for (final char in lower.split('')) {
    buffer.write(accents[char] ?? char);
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Abreviatura usual de los estados de México.
String stateAbbreviation(String state) {
  const abbreviations = {
    'aguascalientes': 'Ags.',
    'baja california': 'B.C.',
    'baja california sur': 'B.C.S.',
    'campeche': 'Camp.',
    'chiapas': 'Chis.',
    'chihuahua': 'Chih.',
    'ciudad de mexico': 'CDMX',
    'coahuila': 'Coah.',
    'coahuila de zaragoza': 'Coah.',
    'colima': 'Col.',
    'durango': 'Dgo.',
    'estado de mexico': 'Edomex',
    'mexico': 'Edomex',
    'guanajuato': 'Gto.',
    'guerrero': 'Gro.',
    'hidalgo': 'Hgo.',
    'jalisco': 'Jal.',
    'michoacan': 'Mich.',
    'michoacan de ocampo': 'Mich.',
    'morelos': 'Mor.',
    'nayarit': 'Nay.',
    'nuevo leon': 'N.L.',
    'oaxaca': 'Oax.',
    'puebla': 'Pue.',
    'queretaro': 'Qro.',
    'quintana roo': 'Q. Roo',
    'san luis potosi': 'S.L.P.',
    'sinaloa': 'Sin.',
    'sonora': 'Son.',
    'tabasco': 'Tab.',
    'tamaulipas': 'Tamps.',
    'tlaxcala': 'Tlax.',
    'veracruz': 'Ver.',
    'veracruz de ignacio de la llave': 'Ver.',
    'yucatan': 'Yuc.',
    'zacatecas': 'Zac.',
  };

  final key = normalizePlaceName(state);

  if (key.isEmpty) {
    return '';
  }

  return abbreviations[key] ?? state.trim();
}
