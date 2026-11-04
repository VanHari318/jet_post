import 'package:cloud_firestore/cloud_firestore.dart';

/// Thực thể Dữ liệu Cấu hình Hệ thống (System Settings Singleton)
/// Lưu trữ biểu cước xe, tỷ lệ hoa hồng chiết khấu và tham số thời gian toàn nền tảng
/// Document ID cố định: system_settings/global_config
class SystemSettingsModel {
  static const String documentId = 'global_config';

  final double basePriceRide; // Giá mở cửa xe ôm (0 - 2km đầu, VNĐ)
  final double pricePerKmRide; // Giá mỗi km tiếp theo của xe ôm (VNĐ)
  final double basePriceDelivery; // Giá mở cửa giao hàng (0 - 2km đầu, VNĐ)
  final double pricePerKmDelivery; // Giá mỗi km tiếp theo của giao hàng (VNĐ)
  final double pricePerKgDelivery; // Giá mỗi 1 kg khối lượng hàng hóa (VNĐ, mặc định 10.000đ)
  final double fragileSurcharge; // Phụ phí hàng dễ vỡ (VNĐ, mặc định 10.000đ)
  final double expressSurcharge; // Phụ phí giao hỏa tốc (VNĐ, mặc định 20.000đ)
  final double commissionRate; // Tỷ lệ hoa hồng chiết khấu nền tảng (0.15 = 15%)
  final double maxSearchRadiusKm; // Bán kính tối đa quét tìm tài xế quanh điểm đón (km)
  final int driverAcceptTimeoutSeconds; // Thời gian đếm ngược tài xế bấm nhận đơn (15 giây)
  final int radarSearchTimeoutSeconds; // Thời gian đếm ngược khách chờ quét tìm xe (45 giây)
  final DateTime updatedAt; // Thời điểm cập nhật biểu cước
  final String updatedBy; // UID quản trị viên cập nhật

  SystemSettingsModel({
    this.basePriceRide = 15000.0,
    this.pricePerKmRide = 8000.0,
    this.basePriceDelivery = 18000.0,
    this.pricePerKmDelivery = 7000.0,
    this.pricePerKgDelivery = 10000.0,
    this.fragileSurcharge = 10000.0,
    this.expressSurcharge = 20000.0,
    this.commissionRate = 0.15,
    this.maxSearchRadiusKm = 5.0,
    this.driverAcceptTimeoutSeconds = 15,
    this.radarSearchTimeoutSeconds = 45,
    required this.updatedAt,
    this.updatedBy = 'system_admin',
  });

  /// Tính cước xe ôm Upfront theo quãng đường km
  double calculateRidePrice(double distanceKm) {
    if (distanceKm <= 2.0) return basePriceRide;
    return basePriceRide + (distanceKm - 2.0) * pricePerKmRide;
  }

  /// Tính cước giao hàng Upfront theo công thức:
  /// Cước = Cự ly (base + perKm) + Khối lượng (weightKg * pricePerKg) + Dễ vỡ + Hỏa tốc
  double calculateDeliveryPrice(
    double distanceKm, {
    double weightKg = 1.0,
    bool isFragile = false,
    bool isExpress = false,
  }) {
    final double distanceFee = distanceKm <= 2.0
        ? basePriceDelivery
        : basePriceDelivery + (distanceKm - 2.0) * pricePerKmDelivery;
    final double weightFee = (weightKg > 0 ? weightKg : 1.0) * pricePerKgDelivery;
    final double fragileFee = isFragile ? fragileSurcharge : 0.0;
    final double expressFee = isExpress ? expressSurcharge : 0.0;
    return distanceFee + weightFee + fragileFee + expressFee;
  }

  factory SystemSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SystemSettingsModel(
      basePriceRide: (data['basePriceRide'] as num?)?.toDouble() ?? 15000.0,
      pricePerKmRide: (data['pricePerKmRide'] as num?)?.toDouble() ?? 8000.0,
      basePriceDelivery: (data['basePriceDelivery'] as num?)?.toDouble() ?? 18000.0,
      pricePerKmDelivery: (data['pricePerKmDelivery'] as num?)?.toDouble() ?? 7000.0,
      pricePerKgDelivery: (data['pricePerKgDelivery'] as num?)?.toDouble() ?? 10000.0,
      fragileSurcharge: (data['fragileSurcharge'] as num?)?.toDouble() ?? 10000.0,
      expressSurcharge: (data['expressSurcharge'] as num?)?.toDouble() ?? 20000.0,
      commissionRate: (data['commissionRate'] as num?)?.toDouble() ?? 0.15,
      maxSearchRadiusKm: (data['maxSearchRadiusKm'] as num?)?.toDouble() ?? 5.0,
      driverAcceptTimeoutSeconds: (data['driverAcceptTimeoutSeconds'] as num?)?.toInt() ?? 15,
      radarSearchTimeoutSeconds: (data['radarSearchTimeoutSeconds'] as num?)?.toInt() ?? 45,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: data['updatedBy'] as String? ?? 'system_admin',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'basePriceRide': basePriceRide,
      'pricePerKmRide': pricePerKmRide,
      'basePriceDelivery': basePriceDelivery,
      'pricePerKmDelivery': pricePerKmDelivery,
      'pricePerKgDelivery': pricePerKgDelivery,
      'fragileSurcharge': fragileSurcharge,
      'expressSurcharge': expressSurcharge,
      'commissionRate': commissionRate,
      'maxSearchRadiusKm': maxSearchRadiusKm,
      'driverAcceptTimeoutSeconds': driverAcceptTimeoutSeconds,
      'radarSearchTimeoutSeconds': radarSearchTimeoutSeconds,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }
}
