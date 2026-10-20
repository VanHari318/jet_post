import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../utils/geo_calculator.dart';

/// Kết quả tính toán tuyến đường từ OpenRouteService
class RouteResult {
  final double distanceKm;
  final double durationMinutes;
  final List<LatLng> polylinePoints;
  final String? encodedGeometry;

  RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
    this.encodedGeometry,
  });
}

/// Kết quả tìm kiếm địa điểm (Geocoding)
class PlaceResult {
  final String displayName;
  final double latitude;
  final double longitude;

  PlaceResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

/// Client kết nối API OpenRouteService / Nominatim OpenStreetMap
class OpenRouteClient {
  // Key dùng để gọi API OpenRouteService (miễn phí 2000 req/ngày)
  // Có thể thay thế bằng API Key cá nhân từ openrouteservice.org
  static String apiKey = '5b3ce3597851110001cf6248c772c91a329d479eb7362df2ba77e641';

  static const String _baseUrl = 'https://api.openrouteservice.org';
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org';

  /// Tìm kiếm địa điểm theo tên đường / địa chỉ (Geocoding)
  static Future<List<PlaceResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_nominatimUrl/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=vn&limit=5',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'JetPost_Transportation_App/1.0'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) {
          return PlaceResult(
            displayName: item['display_name'] ?? '',
            latitude: double.parse(item['lat'].toString()),
            longitude: double.parse(item['lon'].toString()),
          );
        }).toList();
      }
    } catch (_) {
      // Bắt lỗi mạng an toàn
    }
    return [];
  }

  /// Tính khoảng cách, thời gian và tọa độ vẽ tuyến đường Polyline giữa 2 điểm
  static Future<RouteResult> getDirections(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/v2/directions/driving-car?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final properties = features[0]['properties']['summary'];
          final geometry = features[0]['geometry']['coordinates'] as List;

          final double distanceKm = (properties['distance'] as num) / 1000.0;
          final double durationMinutes = (properties['duration'] as num) / 60.0;

          final List<LatLng> polylinePoints = geometry.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          return RouteResult(
            distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
            durationMinutes: double.parse(durationMinutes.toStringAsFixed(0)),
            polylinePoints: polylinePoints,
          );
        }
      }
    } catch (_) {
      // Dự phòng tính toán đường thẳng bằng công thức Haversine nếu mạng chậm hoặc lỗi API Key
    }

    // Fallback: Tuyến đường chim bay nối thẳng 2 điểm
    final fallbackDist = GeoCalculator.distanceInKm(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    return RouteResult(
      distanceKm: double.parse(fallbackDist.toStringAsFixed(2)),
      durationMinutes: double.parse((fallbackDist * 2.5).toStringAsFixed(0)),
      polylinePoints: [start, end],
    );
  }
}
