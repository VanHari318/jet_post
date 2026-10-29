import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_enums.dart';

/// Thực thể Dữ liệu Đơn Giao Hàng Bưu Kiện (Deliveries Collection)
/// Tích hợp cơ chế bàn giao an toàn chuẩn logistics: Mã OTP 4 số và ảnh chụp PoD
class DeliveryModel {
  final String id; // Mã đơn vận Auto ID
  final String senderId; // UID người gửi hàng
  final String senderName; // Họ tên người gửi
  final String senderPhone; // SĐT người gửi
  final String receiverName; // Họ tên người nhận hàng
  final String receiverPhone; // SĐT người nhận hàng (dùng tra cứu đơn)
  final String packageType; // Loại hàng: Tài liệu | Đồ ăn | Hàng nặng
  final String? packageNote; // Ghi chú bưu gửi (VD: Hàng dễ vỡ, gọi trước)
  final String? driverId; // UID tài xế tiếp nhận giao
  final String? driverName; // Họ tên tài xế
  final String? driverPhone; // SĐT tài xế
  final String? driverPlate; // Biển số xe máy
  final String pickupAddress; // Địa chỉ lấy hàng
  final double pickupLat; // Vĩ độ lấy hàng
  final double pickupLng; // Kinh độ lấy hàng
  final String dropoffAddress; // Địa chỉ giao hàng
  final double dropoffLat; // Vĩ độ giao hàng
  final double dropoffLng; // Kinh độ giao hàng
  final String pickupGeohash; // Mã Geohash điểm lấy hàng
  final double distanceKm; // Quãng đường giao hàng (km)
  final double price; // Cước tiền mặt cố định (VNĐ)
  final double codAmount; // Tiền thu hộ COD (VNĐ)
  final String paymentMethod; // Phương thức thanh toán (mặc định: CASH)
  final String? routePolyline; // Tọa độ tuyến đường chỉ dẫn
  final String?
  handoverOtp; // Mã OTP 4 số bảo mật do hệ thống sinh cho Người nhận
  final String?
  podPhotoUrl; // Ảnh chụp gói hàng tại nơi giao (Proof of Delivery)
  final DeliveryStatus status; // Trạng thái chu trình giao hàng
  final String? cancelReason; // Lý do hủy đơn
  final String? cancelledBy; // customer | driver | system
  final int? rating; // Chấm sao chất lượng giao hàng
  final String? reviewComment; // Nhận xét của người gửi
  final DateTime createdAt; // Thời điểm tạo vận đơn
  final DateTime? acceptedAt; // Thời điểm tài xế tiếp nhận
  final DateTime? deliveredAt; // Thời điểm hoàn tất giao hàng PoD

  DeliveryModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
    required this.packageType,
    this.packageNote,
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
    this.codAmount = 0,
    this.paymentMethod = 'CASH',
    this.routePolyline,
    this.handoverOtp,
    this.podPhotoUrl,
    this.status = DeliveryStatus.pendingDriver,
    this.cancelReason,
    this.cancelledBy,
    this.rating,
    this.reviewComment,
    required this.createdAt,
    this.acceptedAt,
    this.deliveredAt,
  });

  factory DeliveryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DeliveryModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      senderPhone: data['senderPhone'] as String? ?? '',
      receiverName: data['receiverName'] as String? ?? '',
      receiverPhone: data['receiverPhone'] as String? ?? '',
      packageType: data['packageType'] as String? ?? 'Bưu phẩm',
      packageNote: data['packageNote'] as String?,
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
      codAmount: (data['codAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'CASH',
      routePolyline: data['routePolyline'] as String?,
      handoverOtp: data['handoverOtp'] as String?,
      podPhotoUrl: data['podPhotoUrl'] as String?,
      status: DeliveryStatus.fromFirestore(data['status'] as String?),
      cancelReason: data['cancelReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
      rating: (data['rating'] as num?)?.toInt(),
      reviewComment: data['reviewComment'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'packageType': packageType,
      'packageNote': packageNote,
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
      'codAmount': codAmount,
      'paymentMethod': paymentMethod,
      'routePolyline': routePolyline,
      'handoverOtp': handoverOtp,
      'podPhotoUrl': podPhotoUrl,
      'status': status.toFirestore(),
      'cancelReason': cancelReason,
      'cancelledBy': cancelledBy,
      'rating': rating,
      'reviewComment': reviewComment,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
    };
  }

  DeliveryModel copyWith({
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverPlate,
    String? handoverOtp,
    String? podPhotoUrl,
    DeliveryStatus? status,
    String? cancelReason,
    String? cancelledBy,
    int? rating,
    String? reviewComment,
    DateTime? acceptedAt,
    DateTime? deliveredAt,
  }) {
    return DeliveryModel(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderPhone: senderPhone,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      packageType: packageType,
      packageNote: packageNote,
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
      codAmount: codAmount,
      paymentMethod: paymentMethod,
      routePolyline: routePolyline,
      handoverOtp: handoverOtp ?? this.handoverOtp,
      podPhotoUrl: podPhotoUrl ?? this.podPhotoUrl,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      rating: rating ?? this.rating,
      reviewComment: reviewComment ?? this.reviewComment,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }
}
