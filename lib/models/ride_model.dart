import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_enums.dart';

/// Thực thể Dữ liệu Cuốc Xe Ôm Công Nghệ (Rides Collection)
class RideModel {
  final String id; // Mã cuốc xe Auto ID
  final String customerId; // UID khách đặt xe
  final String customerName; // Họ tên khách hàng
  final String customerPhone; // SĐT khách hàng
  final String? driverId; // UID tài xế nhận cuốc
  final String? driverName; // Họ tên tài xế
  final String? driverPhone; // SĐT tài xế
  final String? driverPlate; // Biển số xe máy đón
  final String pickupAddress; // Tên địa chỉ điểm đón
  final double pickupLat; // Vĩ độ điểm đón
  final double pickupLng; // Kinh độ điểm đón
  final String dropoffAddress; // Tên địa chỉ điểm trả
  final double dropoffLat; // Vĩ độ điểm trả
  final double dropoffLng; // Kinh độ điểm trả
  final String pickupGeohash; // Mã Geohash quét tài xế
  final double distanceKm; // Quãng đường tính toán (km)
  final double price; // Cước tiền mặt cố định (VNĐ)
  final String paymentMethod; // Phương thức thanh toán (mặc định: CASH)
  final String? routePolyline; // Chuỗi tọa độ vẽ tuyến đường
  final RideStatus status; // Trạng thái chu trình cuốc xe
  final String? cancelReason; // Lý do hủy chuyến
  final String? cancelledBy; // customer | driver | system
  final int? rating; // Chấm sao chất lượng (1-5 sao)
  final String? reviewComment; // Nhận xét của khách hàng
  final DateTime createdAt; // Thời điểm tạo cuốc
  final DateTime? acceptedAt; // Thời điểm tài xế nhận cuốc
  final DateTime? completedAt; // Thời điểm hoàn thành chuyến đi

  RideModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.pickupGeohash,
    required this.distanceKm,
    required this.price,
    this.paymentMethod = 'CASH',
    this.routePolyline,
    this.status = RideStatus.pendingDriver,
    this.cancelReason,
    this.cancelledBy,
    this.rating,
    this.reviewComment,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
  });

  factory RideModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RideModel(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      driverId: data['driverId'] as String?,
      driverName: data['driverName'] as String?,
      driverPhone: data['driverPhone'] as String?,
      driverPlate: data['driverPlate'] as String?,
      pickupAddress: data['pickupAddress'] as String? ?? '',
      pickupLat: (data['pickupLat'] as num?)?.toDouble() ?? 0.0,
      pickupLng: (data['pickupLng'] as num?)?.toDouble() ?? 0.0,
      dropoffAddress: data['dropoffAddress'] as String? ?? '',
      dropoffLat: (data['dropoffLat'] as num?)?.toDouble() ?? 0.0,
      dropoffLng: (data['dropoffLng'] as num?)?.toDouble() ?? 0.0,
      pickupGeohash: data['pickupGeohash'] as String? ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'CASH',
      routePolyline: data['routePolyline'] as String?,
      status: RideStatus.fromFirestore(data['status'] as String?),
      cancelReason: data['cancelReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
      rating: (data['rating'] as num?)?.toInt(),
      reviewComment: data['reviewComment'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverPlate': driverPlate,
      'pickupAddress': pickupAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffAddress': dropoffAddress,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'pickupGeohash': pickupGeohash,
      'distanceKm': distanceKm,
      'price': price,
      'paymentMethod': paymentMethod,
      'routePolyline': routePolyline,
      'status': status.toFirestore(),
      'cancelReason': cancelReason,
      'cancelledBy': cancelledBy,
      'rating': rating,
      'reviewComment': reviewComment,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  RideModel copyWith({
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverPlate,
    RideStatus? status,
    String? cancelReason,
    String? cancelledBy,
    int? rating,
    String? reviewComment,
    DateTime? acceptedAt,
    DateTime? completedAt,
  }) {
    return RideModel(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverPlate: driverPlate ?? this.driverPlate,
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffAddress: dropoffAddress,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      pickupGeohash: pickupGeohash,
      distanceKm: distanceKm,
      price: price,
      paymentMethod: paymentMethod,
      routePolyline: routePolyline,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      rating: rating ?? this.rating,
      reviewComment: reviewComment ?? this.reviewComment,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
