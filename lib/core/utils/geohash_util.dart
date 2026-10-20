/// Thuật toán mã hóa Geohash phục vụ việc quét tìm tài xế lân cận trên Cloud Firestore
/// Tuân thủ chuẩn mã hóa địa lý quốc tế Base32.
class GeohashUtil {
  GeohashUtil._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Mã hóa cặp tọa độ [latitude, longitude] thành chuỗi Geohash với độ chính xác [precision]
  /// Độ dài 5 ký tự ~ sai số ±2.4km (quét radar phù hợp cho đặt xe máy)
  /// Độ dài 6 ký tự ~ sai số ±610m (quét rất gần)
  static String encode(double latitude, double longitude, {int precision = 5}) {
    double minLat = -90.0, maxLat = 90.0;
    double minLng = -180.0, maxLng = 180.0;

    final StringBuffer buffer = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (buffer.length < precision) {
      if (isEven) {
        final double mid = (minLng + maxLng) / 2;
        if (longitude >= mid) {
          ch |= (1 << (4 - bit));
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final double mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  /// Trả về khoảng truy vấn prefix Geohash cho Firestore (Range Query)
  /// Ví dụ: với chuỗi "w4rqs", truy vấn từ "w4rqs" đến "w4rqs~"
  static List<String> getSearchBounds(String geohash) {
    return [geohash, '$geohash~'];
  }
}
