import 'dart:math' as math;

const double ankaraCenterLatitude = 39.92077;
const double ankaraCenterLongitude = 32.85411;
const double ankaraDetectionRadiusKm = 85;
const double ankaraMaxVisibleRadiusKm = 50;

const List<double> defaultRadiusOptionsKm = [1, 3, 5, 10, 25];
const List<double> ankaraRadiusOptionsKm = [1, 3, 5, 10, 25, 50];

double distanceKmBetween({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  const earthRadiusKm = 6371.0;
  final lat1 = _degreesToRadians(fromLatitude);
  final lat2 = _degreesToRadians(toLatitude);
  final deltaLat = _degreesToRadians(toLatitude - fromLatitude);
  final deltaLon = _degreesToRadians(toLongitude - fromLongitude);

  final a =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLon / 2) *
          math.sin(deltaLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadiusKm * c;
}

bool isLocationInAnkara({required double latitude, required double longitude}) {
  final distanceFromCenter = distanceKmBetween(
    fromLatitude: latitude,
    fromLongitude: longitude,
    toLatitude: ankaraCenterLatitude,
    toLongitude: ankaraCenterLongitude,
  );

  return distanceFromCenter <= ankaraDetectionRadiusKm;
}

List<double> radiusOptionsForLocation({
  required double latitude,
  required double longitude,
}) {
  return isLocationInAnkara(latitude: latitude, longitude: longitude)
      ? ankaraRadiusOptionsKm
      : defaultRadiusOptionsKm;
}

double effectiveRadiusKmForLocation({
  required double requestedRadiusKm,
  required double latitude,
  required double longitude,
}) {
  final options = radiusOptionsForLocation(
    latitude: latitude,
    longitude: longitude,
  );

  if (options.contains(requestedRadiusKm)) {
    return requestedRadiusKm;
  }

  final allowedOptions = options
      .where((option) => option <= requestedRadiusKm)
      .toList(growable: false);

  return allowedOptions.isEmpty ? options.first : allowedOptions.last;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;
