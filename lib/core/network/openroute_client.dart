import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../utils/geo_calculator.dart';

/// Kết quả tính toán tuyến đường
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

/// Kết quả tìm kiếm địa điểm (Geocoding & Autocomplete) chuẩn Google Maps style
class PlaceResult {
  final String title;
  final String subtitle;
  final String displayName;
  final double latitude;
  final double longitude;
  final String category; // 'school', 'hospital', 'mall', 'transit', 'airport', 'attraction', 'general'

  PlaceResult({
    required this.title,
    required this.subtitle,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.category = 'general',
  });
}

/// Client kết nối hệ thống bản đồ (OSRM Routing, OpenRouteService, Nominatim Geocoding)
class OpenRouteClient {
  static String openRouteApiKey =
      '5b3ce3597851110001cf6248c772c91a329d479eb7362df2ba77e641';

  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  static const String _openRouteBaseUrl = 'https://api.openrouteservice.org';
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org';
  static const String _photonUrl = 'https://photon.komoot.io/api';

  /// Tra cứu địa chỉ thực tế từ tọa độ GPS (Reverse Geocoding)
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        '$_nominatimUrl/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'JetPost_Transportation_App/1.0 (contact: support@jetpost.vn)'
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Danh sách các địa danh nổi bật phổ biến tại Hà Nội & Việt Nam để gợi ý tức thì
  static final List<PlaceResult> popularPlaces = [
    PlaceResult(
      title: 'Đại học Thủy Lợi',
      subtitle: '175 Tây Sơn, Trung Liệt, Đống Đa, Hà Nội',
      displayName: 'Trường Đại học Thủy Lợi, 175 Tây Sơn, Đống Đa, Hà Nội',
      latitude: 21.0074,
      longitude: 105.8248,
      category: 'school',
    ),
    PlaceResult(
      title: 'Đại học Bách Khoa Hà Nội',
      subtitle: '1 Đại Cồ Việt, Bách Khoa, Hai Bà Trưng, Hà Nội',
      displayName:
          'Đại học Bách Khoa Hà Nội, 1 Đại Cồ Việt, Hai Bà Trưng, Hà Nội',
      latitude: 21.0056,
      longitude: 105.8433,
      category: 'school',
    ),
    PlaceResult(
      title: 'Đại học Quốc Gia Hà Nội',
      subtitle: '144 Xuân Thủy, Dịch Vọng Hậu, Cầu Giấy, Hà Nội',
      displayName: 'Đại học Quốc Gia Hà Nội, 144 Xuân Thủy, Cầu Giấy, Hà Nội',
      latitude: 21.0378,
      longitude: 105.7828,
      category: 'school',
    ),
    PlaceResult(
      title: 'Bệnh viện Bạch Mai',
      subtitle: '78 Giải Phóng, Phương Mai, Đống Đa, Hà Nội',
      displayName: 'Bệnh viện Bạch Mai, 78 Giải Phóng, Đống Đa, Hà Nội',
      latitude: 21.0007,
      longitude: 105.8407,
      category: 'hospital',
    ),
    PlaceResult(
      title: 'Bệnh viện Quân đội 108',
      subtitle: '1 Trần Hưng Đạo, Bạch Đằng, Hai Bà Trưng, Hà Nội',
      displayName: 'Bệnh viện 108, 1 Trần Hưng Đạo, Hai Bà Trưng, Hà Nội',
      latitude: 21.0189,
      longitude: 105.8617,
      category: 'hospital',
    ),
    PlaceResult(
      title: 'Hồ Hoàn Kiếm (Hồ Gươm)',
      subtitle: 'Hàng Trống, Hoàn Kiếm, Hà Nội',
      displayName: 'Hồ Hoàn Kiếm, Phố đi bộ Hồ Gươm, Hoàn Kiếm, Hà Nội',
      latitude: 21.0285,
      longitude: 105.8542,
      category: 'attraction',
    ),
    PlaceResult(
      title: 'Lăng Chủ tịch Hồ Chí Minh',
      subtitle: '2 Hùng Vương, Điện Biên, Ba Đình, Hà Nội',
      displayName: 'Lăng Bác, 2 Hùng Vương, Ba Đình, Hà Nội',
      latitude: 21.0368,
      longitude: 105.8346,
      category: 'attraction',
    ),
    PlaceResult(
      title: 'Vincom Mega Mall Royal City',
      subtitle: '72A Nguyễn Trãi, Thượng Đình, Thanh Xuân, Hà Nội',
      displayName: 'Vincom Royal City, 72A Nguyễn Trãi, Thanh Xuân, Hà Nội',
      latitude: 21.0028,
      longitude: 105.8159,
      category: 'mall',
    ),
    PlaceResult(
      title: 'Vincom Mega Mall Times City',
      subtitle: '458 Minh Khai, Vĩnh Tuy, Hai Bà Trưng, Hà Nội',
      displayName: 'Vincom Times City, 458 Minh Khai, Hai Bà Trưng, Hà Nội',
      latitude: 20.9947,
      longitude: 105.8681,
      category: 'mall',
    ),
    PlaceResult(
      title: 'Bến xe Mỹ Đình',
      subtitle: '20 Phạm Hùng, Mỹ Đình 2, Nam Từ Liêm, Hà Nội',
      displayName: 'Bến xe Mỹ Đình, 20 Phạm Hùng, Nam Từ Liêm, Hà Nội',
      latitude: 21.0284,
      longitude: 105.7778,
      category: 'transit',
    ),
    PlaceResult(
      title: 'Bến xe Giáp Bát',
      subtitle: 'Km6 Đường Giải Phóng, Giáp Bát, Hoàng Mai, Hà Nội',
      displayName: 'Bến xe Giáp Bát, Giải Phóng, Hoàng Mai, Hà Nội',
      latitude: 20.9818,
      longitude: 105.8415,
      category: 'transit',
    ),
    PlaceResult(
      title: 'Sân bay Quốc tế Nội Bài',
      subtitle: 'Phú Minh, Sóc Sơn, Hà Nội',
      displayName: 'Sân bay Quốc tế Nội Bài, Sóc Sơn, Hà Nội',
      latitude: 21.2187,
      longitude: 105.8042,
      category: 'airport',
    ),
  ];

  /// Loại bỏ dấu tiếng Việt để đối sánh tìm kiếm nhanh không dấu
  static String _removeDiacritics(String str) {
    var withDia =
        'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    var withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var result = str.toLowerCase();
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  /// Tìm kiếm địa điểm theo tên đường / địa chỉ (Dual-Engine: Nominatim + Photon with Proximity Biasing)
  static Future<List<PlaceResult>> searchPlaces(
    String query, {
    double? userLat,
    double? userLng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return popularPlaces;
    }

    // 1. Kiểm tra nếu người dùng nhập chuỗi tọa độ (VD: "20.9094, 105.8851" hoặc "Tọa độ: 20.9094, 105.8851")
    final coordRegex = RegExp(
        r'(?:Tọa độ:\s*)?([0-9]{1,2}(?:\.[0-9]+)?)[,\s]+([0-9]{2,3}(?:\.[0-9]+)?)');
    final match = coordRegex.firstMatch(cleanQuery);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null && lat >= -90 && lat <= 90) {
        return [
          PlaceResult(
            title: 'Vị trí theo tọa độ',
            subtitle: '$lat, $lng',
            displayName: 'Tọa độ: $lat, $lng',
            latitude: lat,
            longitude: lng,
            category: 'general',
          ),
        ];
      }
    }

    final List<PlaceResult> results = [];
    final normalizedQuery = _removeDiacritics(cleanQuery);

    // 2. Tìm kiếm nhanh trong danh mục địa danh nổi tiếng có sẵn (Local Instant Match)
    for (final place in popularPlaces) {
      final nameNorm = _removeDiacritics(place.title);
      final subNorm = _removeDiacritics(place.subtitle);
      if (nameNorm.contains(normalizedQuery) ||
          subNorm.contains(normalizedQuery)) {
        results.add(place);
      }
    }

    // 3. ĐỘNG CƠ 1: Photon OSM Geocoding (Elasticsearch mờ, hỗ trợ viết tắt, lỗi chính tả & định vị gần)
    try {
      String photonUrlStr = '$_photonUrl?q=${Uri.encodeComponent(cleanQuery)}&limit=6&lang=vi';
      if (userLat != null && userLng != null) {
        photonUrlStr += '&lat=$userLat&lon=$userLng';
      }

      final photonResponse = await http.get(
        Uri.parse(photonUrlStr),
        headers: {'User-Agent': 'JetPost_Transportation_App/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (photonResponse.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(photonResponse.body);
        final features = data['features'] as List? ?? [];

        for (final f in features) {
          final geometry = f['geometry'] as Map<String, dynamic>?;
          final properties = f['properties'] as Map<String, dynamic>? ?? {};

          if (geometry != null && geometry['coordinates'] is List) {
            final coords = geometry['coordinates'] as List;
            final lon = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();

            final name = (properties['name'] ?? properties['street'] ?? '')
                .toString()
                .trim();
            if (name.isEmpty) continue;

            final street = (properties['street'] ?? '').toString().trim();
            final district =
                (properties['district'] ?? properties['county'] ?? '')
                    .toString()
                    .trim();
            final city =
                (properties['city'] ?? properties['state'] ?? 'Việt Nam')
                    .toString()
                    .trim();

            final subParts = [street, district, city]
                .where((s) => s.isNotEmpty && s != name)
                .toList();
            final subtitle =
                subParts.isNotEmpty ? subParts.join(', ') : 'Việt Nam';
            final fullDisplay = '$name, $subtitle';

            final isDuplicate = results.any(
              (r) =>
                  (r.latitude - lat).abs() < 0.001 &&
                  (r.longitude - lon).abs() < 0.001,
            );

            if (!isDuplicate) {
              results.add(PlaceResult(
                title: name,
                subtitle: subtitle,
                displayName: fullDisplay,
                latitude: lat,
                longitude: lon,
                category: _detectCategory(fullDisplay, properties),
              ));
            }
          }
        }
      }
    } catch (_) {
      // Bắt lỗi photon an toàn
    }

    // 4. ĐỘNG CƠ 2: Nominatim OpenStreetMap (Kèm Proximity Biasing qua viewbox quanh vị trí hiện tại)
    try {
      String nominatimUrlStr =
          '$_nominatimUrl/search?format=json&q=${Uri.encodeComponent(cleanQuery)}&countrycodes=vn&addressdetails=1&limit=6&accept-language=vi';

      // Ưu tiên bán kính ~35km quanh vị trí khách hàng hiện tại
      if (userLat != null && userLng != null) {
        final minLng = userLng - 0.35;
        final maxLng = userLng + 0.35;
        final minLat = userLat - 0.35;
        final maxLat = userLat + 0.35;
        nominatimUrlStr += '&viewbox=$minLng,$maxLat,$maxLng,$minLat&bounded=0';
      }

      final response = await http.get(
        Uri.parse(nominatimUrlStr),
        headers: {
          'User-Agent':
              'JetPost_Transportation_App/1.0 (contact: support@jetpost.vn)'
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        for (final item in data) {
          final lat = double.parse(item['lat'].toString());
          final lon = double.parse(item['lon'].toString());
          final fullDisplay = (item['display_name'] ?? '').toString();

          final address = item['address'] as Map<String, dynamic>?;
          String title = '';
          String subtitle = '';

          if (address != null) {
            title = address['amenity'] ??
                address['road'] ??
                address['suburb'] ??
                address['quarter'] ??
                fullDisplay.split(',').first.trim();
            final district = address['district'] ??
                address['city_district'] ??
                address['suburb'] ??
                '';
            final city = address['city'] ?? address['state'] ?? 'Việt Nam';
            subtitle = [district, city].where((s) => s.isNotEmpty).join(', ');
          }

          if (title.isEmpty) {
            final parts = fullDisplay.split(',');
            title = parts.first.trim();
            subtitle = parts.skip(1).take(2).join(',').trim();
          }

          final isDuplicate = results.any(
            (r) =>
                (r.latitude - lat).abs() < 0.001 &&
                (r.longitude - lon).abs() < 0.001,
          );

          if (!isDuplicate) {
            results.add(PlaceResult(
              title: title,
              subtitle: subtitle.isNotEmpty ? subtitle : fullDisplay,
              displayName: fullDisplay,
              latitude: lat,
              longitude: lon,
              category: _detectCategory(fullDisplay, address),
            ));
          }
        }
      }
    } catch (_) {
      // Bắt lỗi mạng hoặc timeout an toàn
    }

    return results;
  }

  /// Nhận diện phân loại địa điểm để hiển thị Icon tương ứng như Google Maps
  static String _detectCategory(
      String displayName, Map<String, dynamic>? address) {
    final lower = displayName.toLowerCase();
    if (lower.contains('trường') ||
        lower.contains('đại học') ||
        lower.contains('tiểu học') ||
        lower.contains('school') ||
        lower.contains('university')) {
      return 'school';
    }
    if (lower.contains('bệnh viện') ||
        lower.contains('phòng khám') ||
        lower.contains('hospital') ||
        lower.contains('clinic') ||
        lower.contains('y tế')) {
      return 'hospital';
    }
    if (lower.contains('vincom') ||
        lower.contains('aeon') ||
        lower.contains('mall') ||
        lower.contains('siêu thị') ||
        lower.contains('chợ')) {
      return 'mall';
    }
    if (lower.contains('bến xe') ||
        lower.contains('ga tàu') ||
        lower.contains('station') ||
        lower.contains('bus')) {
      return 'transit';
    }
    if (lower.contains('sân bay') || lower.contains('airport')) {
      return 'airport';
    }
    if (lower.contains('công viên') ||
        lower.contains('hồ') ||
        lower.contains('lăng') ||
        lower.contains('chùa') ||
        lower.contains('đền')) {
      return 'attraction';
    }
    return 'general';
  }

  /// Tính khoảng cách, thời gian và tọa độ vẽ tuyến đường Polyline giữa 2 điểm
  /// Sử dụng kiến trúc 3 cấp độ (3-Tier Engine):
  /// Cấp 1: OSRM Driving Engine (Miễn phí, chuẩn xác theo đường giao thông OSM, không cần API key)
  /// Cấp 2: OpenRouteService Directions API (Dự phòng online)
  /// Cấp 3: Thuật toán Haversine + Hệ số uốn lượn đường phố 1.35x (Dự phòng offline)
  static Future<RouteResult> getDirections(LatLng start, LatLng end) async {
    final straightDist = GeoCalculator.distanceInKm(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    // Nếu khoảng cách dưới 50m, coi như cùng 1 vị trí
    if (straightDist < 0.05) {
      return RouteResult(
        distanceKm: 0.1,
        durationMinutes: 1,
        polylinePoints: [start, end],
      );
    }

    // -------------------------------------------------------------
    // CẤP 1: OSRM Public Routing Server (Độ chính xác cao, uốn lượn theo đường phố)
    // -------------------------------------------------------------
    try {
      final osrmUrl = Uri.parse(
        '$_osrmBaseUrl/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );

      final response =
          await http.get(osrmUrl).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0];
          final double distanceMeters =
              (firstRoute['distance'] as num).toDouble();
          final double durationSeconds =
              (firstRoute['duration'] as num).toDouble();
          final geometry =
              firstRoute['geometry']['coordinates'] as List<dynamic>;

          final polyline = geometry.map((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          final distKm = distanceMeters / 1000.0;
          final durMin = (durationSeconds / 60.0).clamp(1.0, 999.0);

          return RouteResult(
            distanceKm: double.parse(distKm.toStringAsFixed(2)),
            durationMinutes: double.parse(durMin.toStringAsFixed(0)),
            polylinePoints: polyline,
          );
        }
      }
    } catch (_) {
      // Chuyển sang Cấp 2 nếu OSRM lỗi hoặc timeout
    }

    // -------------------------------------------------------------
    // CẤP 2: OpenRouteService Directions API
    // -------------------------------------------------------------
    try {
      final orsUrl = Uri.parse(
        '$_openRouteBaseUrl/v2/directions/driving-car?api_key=$openRouteApiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}',
      );

      final response =
          await http.get(orsUrl).timeout(const Duration(seconds: 5));
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
      // Chuyển sang Cấp 3 nếu OpenRouteService lỗi
    }

    // -------------------------------------------------------------
    // CẤP 3: DỰ PHÒNG HAVERSINE + HỆ SỐ UỐN LƯỢN ĐƯỜNG PHỐ (1.35x)
    // -------------------------------------------------------------
    final estimatedRoadKm = straightDist * 1.35;
    final estimatedDuration = (estimatedRoadKm * 2.8).clamp(3.0, 300.0);

    return RouteResult(
      distanceKm: double.parse(estimatedRoadKm.toStringAsFixed(2)),
      durationMinutes: double.parse(estimatedDuration.toStringAsFixed(0)),
      polylinePoints: [start, end],
    );
  }
}
