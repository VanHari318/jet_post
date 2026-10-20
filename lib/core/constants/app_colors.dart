import 'package:flutter/material.dart';

/// Bảng màu nhận diện thương hiệu JetPost
/// Được thiết kế theo chuẩn thẩm mỹ ứng dụng giao vận hiện đại (Grab / Shopee Express).
class AppColors {
  AppColors._();

  // Primary & Secondary Brand Colors
  static const Color primary = Color(0xFF00A86B); // Xanh lục ngọc (Jade Green) - Tốc độ & Giao vận
  static const Color primaryDark = Color(0xFF007A4D);
  static const Color primaryLight = Color(0xFFE6F7F0);
  static const Color secondary = Color(0xFFFF6B00); // Cam rực rỡ (Express Orange) - Hỏa tốc & Đơn hàng
  static const Color secondaryLight = Color(0xFFFFF2E6);

  // Accent & Action Colors
  static const Color accent = Color(0xFF1E88E5); // Xanh dương thông tin & công nghệ
  static const Color accentLight = Color(0xFFE3F2FD);

  // Status & Semantic Colors
  static const Color success = Color(0xFF2E7D32); // Thành công / Hoàn thành đơn
  static const Color successBg = Color(0xFFEDF7ED);
  static const Color warning = Color(0xFFF57C00); // Cảnh báo / Đang tìm tài xế
  static const Color warningBg = Color(0xFFFFF4E5);
  static const Color error = Color(0xFFD32F2F); // Lỗi / Đã hủy / Bị khóa
  static const Color errorBg = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF0288D1);
  static const Color infoBg = Color(0xFFE1F5FE);

  // Neutral Colors (Light Theme)
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1D1E);
  static const Color textSecondaryLight = Color(0xFF6C757D);
  static const Color textMutedLight = Color(0xFFADB5BD);
  static const Color borderLight = Color(0xFFE9ECEF);
  static const Color dividerLight = Color(0xFFF1F3F5);

  // Neutral Colors (Dark Theme - Giảm chói mắt cho tài xế chạy đêm)
  static const Color backgroundDark = Color(0xFF121417);
  static const Color surfaceDark = Color(0xFF1C1F24);
  static const Color cardDark = Color(0xFF242830);
  static const Color textPrimaryDark = Color(0xFFF8F9FA);
  static const Color textSecondaryDark = Color(0xFFA0A6B2);
  static const Color textMutedDark = Color(0xFF6C727F);
  static const Color borderDark = Color(0xFF2F3542);
  static const Color dividerDark = Color(0xFF252A34);

  // Special Map & Radar Colors
  static const Color driverOnline = Color(0xFF00C853); // Marker xe online sẵn sàng
  static const Color driverBusy = Color(0xFFFF1744); // Marker xe đang chở khách/giao hàng
  static const Color routePolyline = Color(0xFF0070BA); // Tuyến đường chỉ dẫn trên bản đồ
}
