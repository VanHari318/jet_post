import 'package:geolocator/geolocator.dart';

class DriverLocationException implements Exception {
  final String message;

  const DriverLocationException(this.message);

  @override
  String toString() => message;
}

class DriverLocationService {
  static const LocationSettings _currentPositionSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 20),
  );
  static const LocationSettings _streamSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  static Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DriverLocationException(
        'Vui lòng bật dịch vụ vị trí (GPS) trên thiết bị.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const DriverLocationException(
        'Ứng dụng chưa được cấp quyền truy cập vị trí.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DriverLocationException(
        'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy bật quyền này trong Cài đặt ứng dụng.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: _currentPositionSettings,
    );
  }

  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: _streamSettings,
    );
  }
}
