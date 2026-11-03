import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/geohash_util.dart';
import '../../../models/delivery_model.dart';
import '../../../models/driver_model.dart';
import '../../../models/ride_model.dart';
import '../../../models/saved_address_model.dart';
import '../../../models/system_settings_model.dart';

/// Dịch vụ nghiệp vụ khách hàng (Customer Service)
/// Độc quyền xử lý: Tính cước, tạo cuốc xe, tạo đơn hàng, quản lý đơn nhận,
/// tra cứu hành trình trực tuyến, quản lý địa chỉ đã lưu và đối soát đánh giá.
class CustomerService {
  CustomerService._();
  static final CustomerService instance = CustomerService._();

  SystemSettingsModel? _cachedSettings;
  DateTime? _settingsFetchedAt;

  // -------------------------------------------------------------
  // 1. BIỂU CƯỚC & TÍNH GIÁ UPFRONT
  // -------------------------------------------------------------

  /// Lấy cấu hình hệ thống từ Firestore (có cache 5 phút để tối ưu số lần đọc)
  Future<SystemSettingsModel> getSystemSettings({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedSettings != null &&
        _settingsFetchedAt != null &&
        now.difference(_settingsFetchedAt!).inMinutes < 5) {
      return _cachedSettings!;
    }

    try {
      final doc = await FirebaseService.firestore
          .collection(FirebaseService.colSystemSettings)
          .doc(SystemSettingsModel.documentId)
          .get();

      if (doc.exists) {
        _cachedSettings = SystemSettingsModel.fromFirestore(doc);
      } else {
        _cachedSettings = SystemSettingsModel(updatedAt: now);
      }
      _settingsFetchedAt = now;
      return _cachedSettings!;
    } catch (e) {
      AppLogger.error('CustomerService', 'Lỗi tải biểu cước hệ thống, dùng mặc định', e);
      _cachedSettings = SystemSettingsModel(updatedAt: now);
      return _cachedSettings!;
    }
  }

  /// Tính cước xe ôm Upfront theo khoảng cách km
  Future<double> calculateRidePrice(double distanceKm) async {
    final settings = await getSystemSettings();
    return settings.calculateRidePrice(distanceKm);
  }

  /// Tính cước giao hàng Upfront theo khoảng cách km và phụ phí loại hàng
  Future<double> calculateDeliveryPrice(
    double distanceKm, {
    double packageSurcharge = 0.0,
  }) async {
    final settings = await getSystemSettings();
    return settings.calculateDeliveryPrice(distanceKm) + packageSurcharge;
  }

  // -------------------------------------------------------------
  // 2. TẠO CUỐC XE & ĐƠN HÀNG (TASK 1.1 & 1.2)
  // -------------------------------------------------------------

  /// Tạo cuốc xe ôm JetBike mới trên Firestore
  Future<String> createRideBooking({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required double distanceKm,
    required double price,
    String? routePolyline,
  }) async {
    try {
      final pickupGeohash = GeohashUtil.encode(pickupLat, pickupLng, precision: 5);
      final ridesRef = FirebaseService.firestore.collection(FirebaseService.colRides);
      final newDocRef = ridesRef.doc();

      final ride = RideModel(
        id: newDocRef.id,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        pickupAddress: pickupAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffAddress: dropoffAddress,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        pickupGeohash: pickupGeohash,
        distanceKm: distanceKm,
        price: price,
        paymentMethod: 'CASH',
        routePolyline: routePolyline,
        status: RideStatus.pendingDriver,
        createdAt: DateTime.now(),
      );

      await newDocRef.set(ride.toFirestore());

      AppLogger.userAction('CustomerService', 'Tạo cuốc xe JetBike thành công', {
        'rideId': newDocRef.id,
        'pickup': pickupAddress,
        'dropoff': dropoffAddress,
        'price': price,
      });

      return newDocRef.id;
    } catch (e) {
      AppLogger.error('CustomerService', 'Lỗi tạo cuốc xe', e);
      throw Exception('Không thể tạo cuốc xe: $e');
    }
  }

  /// Tạo đơn giao hàng JetExpress mới kèm mã OTP 4 số bàn giao
  Future<String> createDeliveryBooking({
    required String senderId,
    required String senderName,
    required String senderPhone,
    required String receiverName,
    required String receiverPhone,
    required String packageType,
    String? packageNote,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required double distanceKm,
    required double price,
    double codAmount = 0.0,
    String? routePolyline,
  }) async {
    try {
      final pickupGeohash = GeohashUtil.encode(pickupLat, pickupLng, precision: 5);
      // Sinh mã OTP 4 số bàn giao ngẫu nhiên (1000 - 9999)
      final handoverOtp = (1000 + Random().nextInt(9000)).toString();

      final deliveriesRef = FirebaseService.firestore.collection(FirebaseService.colDeliveries);
      final newDocRef = deliveriesRef.doc();

      final delivery = DeliveryModel(
        id: newDocRef.id,
        senderId: senderId,
        senderName: senderName,
        senderPhone: senderPhone,
        receiverName: receiverName,
        receiverPhone: receiverPhone,
        packageType: packageType,
        packageNote: packageNote,
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
        paymentMethod: 'CASH',
        routePolyline: routePolyline,
        handoverOtp: handoverOtp,
        status: DeliveryStatus.pendingDriver,
        createdAt: DateTime.now(),
      );

      await newDocRef.set(delivery.toFirestore());

      AppLogger.userAction('CustomerService', 'Tạo đơn giao hàng JetExpress thành công', {
        'deliveryId': newDocRef.id,
        'receiverPhone': receiverPhone,
        'handoverOtp': handoverOtp,
        'price': price,
      });

      return newDocRef.id;
    } catch (e) {
      AppLogger.error('CustomerService', 'Lỗi tạo đơn giao hàng', e);
      throw Exception('Không thể tạo đơn giao hàng: $e');
    }
  }

  // -------------------------------------------------------------
  // 3. THEO DÕI HÀNH TRÌNH THỜI GIAN THỰC (TASK 1.3)
  // -------------------------------------------------------------

  /// Stream lắng nghe trạng thái cuốc xe máy
  Stream<RideModel?> streamRide(String rideId) {
    return FirebaseService.firestore
        .collection(FirebaseService.colRides)
        .doc(rideId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return RideModel.fromFirestore(snapshot);
    });
  }

  /// Stream lắng nghe trạng thái đơn giao hàng
  Stream<DeliveryModel?> streamDelivery(String deliveryId) {
    return FirebaseService.firestore
        .collection(FirebaseService.colDeliveries)
        .doc(deliveryId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return DeliveryModel.fromFirestore(snapshot);
    });
  }

  /// Stream lắng nghe tọa độ & thông tin tài xế thực hiện cuốc
  Stream<DriverModel?> streamDriver(String driverId) {
    return FirebaseService.firestore
        .collection(FirebaseService.colDrivers)
        .doc(driverId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return DriverModel.fromFirestore(snapshot);
    });
  }

  // -------------------------------------------------------------
  // 4. HỦY CHUYẾN & NGOẠI LỆ (TASK 1.6)
  // -------------------------------------------------------------

  /// Hủy cuốc xe ôm (Bởi khách hàng hoặc hệ thống khi hết timeout 45s)
  Future<void> cancelRide({
    required String rideId,
    required String reason,
    required String cancelledBy, // 'customer' | 'system'
  }) async {
    try {
      await FirebaseService.firestore
          .collection(FirebaseService.colRides)
          .doc(rideId)
          .update({
        'status': RideStatus.cancelled.toFirestore(),
        'cancelReason': reason,
        'cancelledBy': cancelledBy,
      });

      AppLogger.userAction('CustomerService', 'Hủy cuốc xe JetBike', {
        'rideId': rideId,
        'reason': reason,
        'cancelledBy': cancelledBy,
      });
    } catch (e) {
      AppLogger.error('CustomerService', 'Lỗi hủy cuốc xe', e);
      throw Exception('Không thể hủy cuốc xe: $e');
    }
  }

  /// Hủy đơn giao hàng
  Future<void> cancelDelivery({
    required String deliveryId,
    required String reason,
    required String cancelledBy,
  }) async {
    try {
      await FirebaseService.firestore
          .collection(FirebaseService.colDeliveries)
          .doc(deliveryId)
          .update({
        'status': DeliveryStatus.cancelled.toFirestore(),
        'cancelReason': reason,
        'cancelledBy': cancelledBy,
      });

      AppLogger.userAction('CustomerService', 'Hủy đơn giao hàng JetExpress', {
        'deliveryId': deliveryId,
        'reason': reason,
        'cancelledBy': cancelledBy,
      });
    } catch (e) {
      AppLogger.error('CustomerService', 'Lỗi hủy đơn giao hàng', e);
      throw Exception('Không thể hủy đơn giao hàng: $e');
    }
  }

  // -------------------------------------------------------------
  // 5. TRA CỨU ĐƠN NHẬN CỦA TÔI (TASK 1.4)
  // -------------------------------------------------------------

  /// Stream danh sách đơn bưu phẩm gửi cho khách hàng này (lọc theo receiverPhone)
  Stream<List<DeliveryModel>> streamConsigneeDeliveries(String receiverPhone) {
    if (receiverPhone.isEmpty) return Stream.value([]);

    return FirebaseService.firestore
        .collection(FirebaseService.colDeliveries)
        .where('receiverPhone', isEqualTo: receiverPhone)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((d) => DeliveryModel.fromFirestore(d)).toList();
    });
  }

  // -------------------------------------------------------------
  // 6. HOẠT ĐỘNG & LỊCH SỬ CHUYẾN ĐI (TASK 1.8)
  // -------------------------------------------------------------

  /// Stream toàn bộ danh sách cuốc xe của khách hàng
  Stream<List<RideModel>> streamCustomerRides(String customerId) {
    return FirebaseService.firestore
        .collection(FirebaseService.colRides)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((d) => RideModel.fromFirestore(d)).toList();
    });
  }

  /// Stream toàn bộ danh sách đơn giao hàng của khách gửi
  Stream<List<DeliveryModel>> streamCustomerDeliveries(String senderId) {
    return FirebaseService.firestore
        .collection(FirebaseService.colDeliveries)
        .where('senderId', isEqualTo: senderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((d) => DeliveryModel.fromFirestore(d)).toList();
    });
  }

  // -------------------------------------------------------------
  // 7. ĐÁNH GIÁ CHẤT LƯỢNG & ĐỐI SOÁT (TASK 1.5)
  // -------------------------------------------------------------

  /// Gửi đánh giá cho cuốc xe ôm và cập nhật điểm trung bình tài xế
  Future<void> rateRide({
    required String rideId,
    required String driverId,
    required int rating,
    String? reviewComment,
  }) async {
    try {
      // 1. Cập nhật vào document cuốc xe
      await FirebaseService.firestore
          .collection(FirebaseService.colRides)
          .doc(rideId)
          .update({
        'rating': rating,
        'reviewComment': reviewComment,
      });

      // 2. Cập nhật rating vào tài liệu tài xế
      if (driverId.isNotEmpty) {
        final driverDocRef = FirebaseService.firestore
            .collection(FirebaseService.colDrivers)
            .doc(driverId);

        await FirebaseService.firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(driverDocRef);
          if (snapshot.exists) {
            final driver = DriverModel.fromFirestore(snapshot);
            final oldReviews = driver.totalReviews;
            final oldRating = driver.rating;
            final newTotalReviews = oldReviews + 1;
            final newRating =
                ((oldRating * oldReviews) + rating) / newTotalReviews;

            transaction.update(driverDocRef, {
              'totalReviews': newTotalReviews,
              'rating': double.parse(newRating.toStringAsFixed(2)),
            });
          }
        });
      }

      AppLogger.userAction('CustomerService', 'Đánh giá cuốc xe thành công', {
        'rideId': rideId,
        'driverId': driverId,
        'rating': rating,
      });
    } catch (e) {
      AppLogger.error('CustomerService', 'Lỗi đánh giá cuốc xe', e);
      throw Exception('Không thể gửi đánh giá: $e');
    }
  }

  /// Gửi đánh giá cho đơn giao hàng
  Future<void> rateDelivery({
    required String deliveryId,
    required String driverId,
    required int rating,
    String? reviewComment,
  }) async {
    try {
      await FirebaseService.firestore
          .collection(FirebaseService.colDeliveries)
          .doc(deliveryId)
          .update({
        'rating': rating,
        'reviewComment': reviewComment,
      });

      if (driverId.isNotEmpty) {
        final driverDocRef = FirebaseService.firestore
            .collection(FirebaseService.colDrivers)
            .doc(driverId);

        await FirebaseService.firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(driverDocRef);
          if (snapshot.exists) {
            final driver = DriverModel.fromFirestore(snapshot);
            final oldReviews = driver.totalReviews;
            final oldRating = driver.rating;
            final newTotalReviews = oldReviews + 1;
            final newRating =
                ((oldRating * oldReviews) + rating) / newTotalReviews;

            transaction.update(driverDocRef, {
              'totalReviews': newTotalReviews,
              'rating': double.parse(newRating.toStringAsFixed(2)),
            });
          }
        });
      }

      AppLogger.userAction('CustomerService', 'Đánh giá đơn hàng thành công', {
        'deliveryId': deliveryId,
        'driverId': driverId,
        'rating': rating,
      });
    } catch (e) {
      AppLogger.error('CustomerService', 'Lỗi đánh giá đơn hàng', e);
      throw Exception('Không thể gửi đánh giá: $e');
    }
  }

  // -------------------------------------------------------------
  // 8. QUẢN LÝ ĐỊA CHỈ QUEN THUỘC (TASK 1.7)
  // -------------------------------------------------------------

  /// Stream danh sách địa chỉ đã lưu của người dùng
  Stream<List<SavedAddressModel>> streamSavedAddresses(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return FirebaseService.firestore
        .collection(FirebaseService.colUsers)
        .doc(userId)
        .collection(FirebaseService.subSavedAddresses)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SavedAddressModel.fromFirestore(doc, userId))
          .toList();
    });
  }

  /// Thêm địa chỉ quen thuộc mới
  Future<void> addSavedAddress({
    required String userId,
    required AddressLabel label,
    required String addressText,
    required double lat,
    required double lng,
  }) async {
    try {
      final colRef = FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(userId)
          .collection(FirebaseService.subSavedAddresses);

      await colRef.add({
        'label': label.toFirestore(),
        'addressText': addressText,
        'lat': lat,
        'lng': lng,
        'createdAt': FieldValue.serverTimestamp(),
      });

      AppLogger.userAction('CustomerService', 'Lưu địa chỉ quen thuộc mới', {
        'userId': userId,
        'label': label.toFirestore(),
        'address': addressText,
      });
    } catch (e) {
      AppLogger.error('CustomerService', 'Lỗi lưu địa chỉ', e);
      throw Exception('Không thể lưu địa chỉ: $e');
    }
  }

  /// Xóa địa chỉ quen thuộc
  Future<void> deleteSavedAddress(String userId, String addressId) async {
    try {
      await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(userId)
          .collection(FirebaseService.subSavedAddresses)
          .doc(addressId)
          .delete();

      AppLogger.userAction('CustomerService', 'Xóa địa chỉ quen thuộc', {
        'userId': userId,
        'addressId': addressId,
      });
    } catch (e) {
      AppLogger.error('CustomerService', 'Lỗi xóa địa chỉ', e);
      throw Exception('Không thể xóa địa chỉ: $e');
    }
  }
}

