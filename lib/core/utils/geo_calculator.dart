import 'dart:math' as math;

/// Tiện ích tính toán khoảng cách và góc xoay trên tọa độ cầu địa lý (Haversine Formula)
class GeoCalculator {
  GeoCalculator._();

  static const double earthRadiusKm = 6371.0;

  /// Tính khoảng cách đường chim bay giữa 2 điểm (km) theo công thức Haversine
  static double distanceInKm(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Tính khoảng cách đường chim bay giữa 2 điểm (mét)
  static double distanceInMeters(double lat1, double lng1, double lat2, double lng2) {
    return distanceInKm(lat1, lng1, lat2, lng2) * 1000.0;
  }

  /// Tính góc xoay (Heading/Bearing) từ điểm 1 đến điểm 2 theo độ (0 - 360)
  /// Dùng để xoay icon mũi tên/xe máy trên bản đồ theo hướng di chuyển thực tế
  static double calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final phi1 = _toRadians(lat1);
    final phi2 = _toRadians(lat2);
    final deltaLambda = _toRadians(lng2 - lng1);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final theta = math.atan2(y, x);
    return (_toDegrees(theta) + 360) % 360;
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);
  static double _toDegrees(double radians) => radians * (180.0 / math.pi);
}
