import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_enums.dart';

/// Thực thể Dữ liệu Đối tác Tài xế (Drivers Collection)
/// Quản lý thông tin eKYC, xe máy, tọa độ GPS thời gian thực và trạng thái nhận cuốc
class DriverModel {
  final String id; // Trùng với User ID (UID)
  final String vehicleType; // Loại xe (mặc định: motorcycle)
  final String plateNumber; // Biển số xe máy
  final String? idCardFrontUrl; // Ảnh CCCD mặt trước
  final String? idCardBackUrl; // Ảnh CCCD mặt sau
  final String? licenseUrl; // Ảnh Giấy phép lái xe
  final DriverApprovalStatus status; // PENDING_APPROVAL | ACTIVE | BANNED
  final bool isOnline; // Trạng thái sẵn sàng nhận cuốc
  final bool isBusy; // Đang trong chuyến đi (ngăn nhận cuốc đúp)
  final String? activeTripId; // Mã cuốc xe/đơn hàng đang thực hiện
  final double currentLat; // Vĩ độ GPS hiện tại
  final double currentLng; // Kinh độ GPS hiện tại
  final String geohash; // Mã Geohash độ dài 5-6 ký tự phục vụ quét radar
  final double heading; // Hướng xoay la bàn xe máy (0 - 360 độ)
  final double rating; // Điểm sao uy tín trung bình (1.0 - 5.0)
  final int totalReviews; // Tổng số lượt khách đánh giá
  final int totalTrips; // Tổng số cuốc hoàn thành
  final double walletBalance; // Số dư ví thu nhập thực tế (VNĐ)
  final DateTime lastActiveAt; // Thời điểm phát GPS gần nhất

  DriverModel({
    required this.id,
    this.vehicleType = 'motorcycle',
    required this.plateNumber,
    this.idCardFrontUrl,
    this.idCardBackUrl,
    this.licenseUrl,
    this.status = DriverApprovalStatus.pendingApproval,
    this.isOnline = false,
    this.isBusy = false,
    this.activeTripId,
    this.currentLat = 0.0,
    this.currentLng = 0.0,
    this.geohash = '',
    this.heading = 0.0,
    this.rating = 5.0,
    this.totalReviews = 0,
    this.totalTrips = 0,
    this.walletBalance = 0.0,
    required this.lastActiveAt,
  });

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DriverModel(
      id: doc.id,
      vehicleType: data['vehicleType'] as String? ?? 'motorcycle',
      plateNumber: data['plateNumber'] as String? ?? '',
      idCardFrontUrl: data['idCardFrontUrl'] as String?,
      idCardBackUrl: data['idCardBackUrl'] as String?,
      licenseUrl: data['licenseUrl'] as String?,
      status: DriverApprovalStatus.fromFirestore(data['status'] as String?),
      isOnline: data['isOnline'] as bool? ?? false,
      isBusy: data['isBusy'] as bool? ?? false,
      activeTripId: data['activeTripId'] as String?,
      currentLat: (data['currentLat'] as num?)?.toDouble() ?? 0.0,
      currentLng: (data['currentLng'] as num?)?.toDouble() ?? 0.0,
      geohash: data['geohash'] as String? ?? '',
      heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      totalReviews: (data['totalReviews'] as num?)?.toInt() ?? 0,
      totalTrips: (data['totalTrips'] as num?)?.toInt() ?? 0,
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vehicleType': vehicleType,
      'plateNumber': plateNumber,
      'idCardFrontUrl': idCardFrontUrl,
      'idCardBackUrl': idCardBackUrl,
      'licenseUrl': licenseUrl,
      'status': status.toFirestore(),
      'isOnline': isOnline,
      'isBusy': isBusy,
      'activeTripId': activeTripId,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'geohash': geohash,
      'heading': heading,
      'rating': rating,
      'totalReviews': totalReviews,
      'totalTrips': totalTrips,
      'walletBalance': walletBalance,
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
    };
  }

  DriverModel copyWith({
    String? plateNumber,
    String? idCardFrontUrl,
    String? idCardBackUrl,
    String? licenseUrl,
    DriverApprovalStatus? status,
    bool? isOnline,
    bool? isBusy,
    String? activeTripId,
    double? currentLat,
    double? currentLng,
    String? geohash,
    double? heading,
    double? rating,
    int? totalReviews,
    int? totalTrips,
    double? walletBalance,
    DateTime? lastActiveAt,
  }) {
    return DriverModel(
      id: id,
      vehicleType: vehicleType,
      plateNumber: plateNumber ?? this.plateNumber,
      idCardFrontUrl: idCardFrontUrl ?? this.idCardFrontUrl,
      idCardBackUrl: idCardBackUrl ?? this.idCardBackUrl,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      isBusy: isBusy ?? this.isBusy,
      activeTripId: activeTripId ?? this.activeTripId,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      geohash: geohash ?? this.geohash,
      heading: heading ?? this.heading,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalTrips: totalTrips ?? this.totalTrips,
      walletBalance: walletBalance ?? this.walletBalance,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}
