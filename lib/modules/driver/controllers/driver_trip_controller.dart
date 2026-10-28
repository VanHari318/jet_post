import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../models/delivery_model.dart';
import '../../../models/ride_model.dart';
import '../../../core/constants/app_enums.dart';

/// Loại chuyến đi của tài xế
enum TripType { ride, delivery }

/// Controller quản lý luồng nghiệp vụ khi tài xế đang thực hiện chuyến đi
/// Xử lý: cập nhật trạng thái theo từng bước, hủy chuyến, kết thúc chuyến
class DriverTripController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String tripId;
  final TripType tripType;
  final String driverUid;

  // ── State Notifiers ──────────────────────────────────────────────────────
  final ValueNotifier<RideModel?> currentRide = ValueNotifier(null);
  final ValueNotifier<DeliveryModel?> currentDelivery = ValueNotifier(null);
  final ValueNotifier<bool> isUpdating = ValueNotifier(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  StreamSubscription<DocumentSnapshot>? _tripSub;

  DriverTripController({
    required this.tripId,
    required this.tripType,
    required this.driverUid,
  });

  // ── Khởi tạo: lắng nghe realtime trip document ───────────────────────────
  void init() {
    _listenTrip();
  }

  /// Lắng nghe realtime document của chuyến đang thực hiện
  void _listenTrip() {
    final collection =
        tripType == TripType.ride ? 'rides' : 'deliveries';

    _tripSub = _firestore
        .collection(collection)
        .doc(tripId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      if (tripType == TripType.ride) {
        currentRide.value = RideModel.fromFirestore(snap);
      } else {
        currentDelivery.value = DeliveryModel.fromFirestore(snap);
      }
    }, onError: (e) {
      errorMessage.value = 'Lỗi đồng bộ dữ liệu chuyến đi.';
    });
  }

  // ── Advance Status — Xe Ôm ───────────────────────────────────────────────

  /// Chuyển sang trạng thái kế tiếp cho cuốc xe ôm
  /// accepted → arrivedPickup → inProgress → completed
  Future<bool> advanceRideStatus() async {
    final ride = currentRide.value;
    if (ride == null || isUpdating.value) return false;

    final nextStatus = _nextRideStatus(ride.status);
    if (nextStatus == null) return false;

    isUpdating.value = true;
    errorMessage.value = null;

    try {
      final updateData = <String, dynamic>{
        'status': nextStatus.toFirestore(),
      };

      // Ghi timestamp khi hoàn thành
      if (nextStatus == RideStatus.completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('rides').doc(tripId).update(updateData);

      // Khi hoàn thành → cập nhật lại trạng thái tài xế
      if (nextStatus == RideStatus.completed) {
        await _releaseDriver();
      }

      return true;
    } catch (e) {
      errorMessage.value = 'Không thể cập nhật trạng thái. Vui lòng thử lại.';
      return false;
    } finally {
      isUpdating.value = false;
    }
  }

  /// Tính trạng thái kế tiếp cho RideStatus
  RideStatus? _nextRideStatus(RideStatus current) {
    switch (current) {
      case RideStatus.accepted:
        return RideStatus.arrivedPickup;
      case RideStatus.arrivedPickup:
        return RideStatus.inProgress;
      case RideStatus.inProgress:
        return RideStatus.completed;
      default:
        return null; // Không thể tiến thêm
    }
  }

  // ── Advance Status — Giao Hàng ───────────────────────────────────────────

  /// Chuyển sang trạng thái kế tiếp cho đơn giao hàng
  /// accepted → pickedUp → inTransit → completed
  Future<bool> advanceDeliveryStatus() async {
    final delivery = currentDelivery.value;
    if (delivery == null || isUpdating.value) return false;

    final nextStatus = _nextDeliveryStatus(delivery.status);
    if (nextStatus == null) return false;

    isUpdating.value = true;
    errorMessage.value = null;

    try {
      final updateData = <String, dynamic>{
        'status': nextStatus.toFirestore(),
      };

      // Ghi timestamp khi hoàn thành giao hàng
      if (nextStatus == DeliveryStatus.completed) {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('deliveries').doc(tripId).update(updateData);

      // Khi hoàn thành → cập nhật lại trạng thái tài xế
      if (nextStatus == DeliveryStatus.completed) {
        await _releaseDriver();
      }

      return true;
    } catch (e) {
      errorMessage.value = 'Không thể cập nhật trạng thái. Vui lòng thử lại.';
      return false;
    } finally {
      isUpdating.value = false;
    }
  }

  /// Tính trạng thái kế tiếp cho DeliveryStatus
  DeliveryStatus? _nextDeliveryStatus(DeliveryStatus current) {
    switch (current) {
      case DeliveryStatus.accepted:
        return DeliveryStatus.pickedUp;
      case DeliveryStatus.pickedUp:
        return DeliveryStatus.inTransit;
      case DeliveryStatus.inTransit:
        return DeliveryStatus.completed;
      default:
        return null;
    }
  }

  // ── Hủy Chuyến ───────────────────────────────────────────────────────────

  /// Tài xế hủy chuyến — cập nhật status cancelled lên Firestore
  Future<bool> cancelTrip(String reason) async {
    if (isUpdating.value) return false;
    isUpdating.value = true;
    errorMessage.value = null;

    try {
      final collection =
          tripType == TripType.ride ? 'rides' : 'deliveries';

      final cancelStatus = tripType == TripType.ride
          ? RideStatus.cancelled.toFirestore()
          : DeliveryStatus.cancelled.toFirestore();

      await _firestore.collection(collection).doc(tripId).update({
        'status': cancelStatus,
        'cancelReason': reason,
        'cancelledBy': 'driver',
      });

      // Giải phóng tài xế sau khi hủy
      await _releaseDriver();
      return true;
    } catch (e) {
      errorMessage.value = 'Không thể hủy chuyến. Vui lòng thử lại.';
      return false;
    } finally {
      isUpdating.value = false;
    }
  }

  // ── Helper: Giải phóng tài xế sau khi hoàn thành / hủy ──────────────────

  /// Đặt lại trạng thái tài xế về rảnh và tăng tổng số chuyến (nếu completed)
  Future<void> _releaseDriver() async {
    if (driverUid.isEmpty) return;
    try {
      final isCompleted = tripType == TripType.ride
          ? currentRide.value?.status == RideStatus.completed
          : currentDelivery.value?.status == DeliveryStatus.completed;

      final Map<String, dynamic> updateData = {
        'isBusy': false,
        'activeTripId': null,
        'lastActiveAt': FieldValue.serverTimestamp(),
      };

      // Tăng tổng số chuyến hoàn thành
      if (isCompleted) {
        updateData['totalTrips'] = FieldValue.increment(1);
      }

      await _firestore.collection('drivers').doc(driverUid).update(updateData);
    } catch (_) {
      // Lỗi không critical — tài xế vẫn có thể tiếp tục dùng app
    }
  }

  // ── Getter tiện ích ───────────────────────────────────────────────────────

  /// Lấy nhãn hành động swipe theo trạng thái hiện tại (Xe Ôm)
  String get rideSwipeLabel {
    switch (currentRide.value?.status) {
      case RideStatus.accepted:
        return 'Đã đến điểm đón';
      case RideStatus.arrivedPickup:
        return 'Đã đón khách — Bắt đầu chạy';
      case RideStatus.inProgress:
        return 'Đã đến điểm trả — Kết thúc chuyến';
      default:
        return '';
    }
  }

  /// Lấy nhãn hành động swipe theo trạng thái hiện tại (Giao Hàng)
  String get deliverySwipeLabel {
    switch (currentDelivery.value?.status) {
      case DeliveryStatus.accepted:
        return 'Đã đến lấy hàng';
      case DeliveryStatus.pickedUp:
        return 'Đã lấy hàng — Bắt đầu giao';
      case DeliveryStatus.inTransit:
        return 'Đã đến nơi giao — Hoàn thành đơn';
      default:
        return '';
    }
  }

  /// Lấy nội dung dialog xác nhận (Xe Ôm)
  String get rideConfirmMessage {
    switch (currentRide.value?.status) {
      case RideStatus.accepted:
        return 'Xác nhận bạn đã đến điểm đón khách?';
      case RideStatus.arrivedPickup:
        return 'Xác nhận đã đón khách và bắt đầu di chuyển?';
      case RideStatus.inProgress:
        return 'Xác nhận hoàn thành chuyến đi và trả khách tại điểm đến?';
      default:
        return '';
    }
  }

  /// Lấy nội dung dialog xác nhận (Giao Hàng)
  String get deliveryConfirmMessage {
    switch (currentDelivery.value?.status) {
      case DeliveryStatus.accepted:
        return 'Xác nhận bạn đã đến điểm lấy hàng?';
      case DeliveryStatus.pickedUp:
        return 'Xác nhận đã lấy hàng và bắt đầu giao?';
      case DeliveryStatus.inTransit:
        return 'Xác nhận đã giao hàng thành công tại địa chỉ người nhận?';
      default:
        return '';
    }
  }

  /// Kiểm tra trạng thái hiện tại có thể tiến thêm không
  bool get canAdvance {
    if (tripType == TripType.ride) {
      return _nextRideStatus(
              currentRide.value?.status ?? RideStatus.completed) !=
          null;
    } else {
      return _nextDeliveryStatus(
              currentDelivery.value?.status ?? DeliveryStatus.completed) !=
          null;
    }
  }

  // ── Dọn dẹp ──────────────────────────────────────────────────────────────
  void dispose() {
    _tripSub?.cancel();
    currentRide.dispose();
    currentDelivery.dispose();
    isUpdating.dispose();
    errorMessage.dispose();
  }
}
