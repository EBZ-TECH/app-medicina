import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Obtiene coordenadas del dispositivo (1.6 geolocalización).
class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  /// Devuelve lat/lng o lanza [LocationServiceException] con mensaje en español.
  Future<({double lat, double lng})> getCurrentLatLng() async {
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceException(
          'El servicio de ubicación está desactivado. Actívalo en ajustes del dispositivo.',
        );
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationServiceException(
        'Permiso de ubicación denegado. Actívalo en los ajustes de la app.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'La ubicación está bloqueada. Habilítala en Ajustes → MediConnect.',
      );
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return (lat: pos.latitude, lng: pos.longitude);
  }
}
