import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/delivery_model.dart';
import '../../../models/driver_model.dart';
import '../../../models/ride_model.dart';
import '../../../models/user_model.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/geohash_util.dart';

/// Controller chính của màn hình chờ đơn tài xế (Driver Dashboard)
/// Quản lý: trạng thái online/offline, lắng nghe đơn mới, nhận cuốc/đơn
class DriverDashboardController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── State Notifiers ──────────────────────────────────────────────────────
  final ValueNotifier<bool> isLoading = ValueNotifier(true);
  final ValueNotifier<DriverModel?> driverModel = ValueNotifier(null);
  final ValueNotifier<UserModel?> userModel = ValueNotifier(null);
  final ValueNotifier<bool> isOnline = ValueNotifier(false);
  final ValueNotifier<List<RideModel>> pendingRides = ValueNotifier([]);
  final ValueNotifier<List<DeliveryModel>> pendingDeliveries = ValueNotifier(
    [],
  );
  final ValueNotifier<List<RideModel>> availableRides = ValueNotifier([]);
  final ValueNotifier<List<DeliveryModel>> availableDeliveries = ValueNotifier(
    [],
  );
  final ValueNotifier<bool> isSearchingOrders = ValueNotifier(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  // ── Subscriptions Firestore realtime ─────────────────────────────────────
  StreamSubscription<DocumentSnapshot>? _driverSub;
  StreamSubscription<QuerySnapshot>? _ridesSub;
  StreamSubscription<QuerySnapshot>? _deliveriesSub;
  int _availableOrdersRequestId = 0;

  String get _uid => _auth.currentUser?.uid ?? '';
  String get driverUid => _uid;
  bool get isDemoMode => _uid.isEmpty;

  // ── Khởi tạo: load dữ liệu tài xế và bắt đầu lắng nghe ─────────────────
  Future<void> init() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _loadUserModel();
      _listenDriverModel();
    } catch (e) {
      errorMessage.value = 'Không thể tải dữ liệu tài xế. Vui lòng thử lại.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Load thông tin UserModel (tên, avatar) từ Firestore
  Future<void> _loadUserModel() async {
    if (_uid.isEmpty) return;
    final doc = await _firestore.collection('users').doc(_uid).get();
    if (doc.exists) {
      userModel.value = UserModel.fromFirestore(doc);
    }
  }

  /// Lắng nghe realtime DriverModel — tự cập nhật khi Firestore thay đổi
  void _listenDriverModel() {
    if (_uid.isEmpty) return;
    _driverSub = _firestore
        .collection('drivers')
        .doc(_uid)
        .snapshots()
        .listen(
          (snap) {
            if (snap.exists) {
              final driver = DriverModel.fromFirestore(snap);
              driverModel.value = driver;
              isOnline.value = driver.isOnline;

              // Khi tài xế online → bắt đầu lắng nghe đơn mới
              if (driver.isOnline && !driver.isBusy) {
                _startListeningOrders();
              } else {
                // Offline hoặc đang bận → dừng lắng nghe đơn mới
                _stopListeningOrders();
              }
            }
          },
          onError: (e) {
            errorMessage.value = 'Lỗi đồng bộ dữ liệu tài xế.';
          },
        );
  }

  /// Bắt đầu lắng nghe đơn xe ôm và giao hàng đang chờ tài xế
  void _startListeningOrders() {
    _startListeningRides();
    _startListeningDeliveries();
  }

  /// Lắng nghe danh sách cuốc xe ôm đang chờ (PENDING_DRIVER)
  void _startListeningRides() {
    _ridesSub?.cancel();
    _ridesSub = _firestore
        .collection('rides')
        .where('status', isEqualTo: RideStatus.pendingDriver.toFirestore())
        .limit(50)
        .snapshots()
        .listen(
          (snap) {
            final rides =
                snap.docs.map((doc) => RideModel.fromFirestore(doc)).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            pendingRides.value = rides.take(5).toList();
          },
          onError: (Object error) {
            pendingRides.value = [];
            errorMessage.value = 'Không thể cập nhật danh sách cuốc xe.';
          },
        );
  }

  /// Lắng nghe danh sách đơn giao hàng đang chờ (PENDING_DRIVER)
  void _startListeningDeliveries() {
    _deliveriesSub?.cancel();
    _deliveriesSub = _firestore
        .collection('deliveries')
        .where('status', isEqualTo: DeliveryStatus.pendingDriver.toFirestore())
        .limit(50)
        .snapshots()
        .listen(
          (snap) {
            final deliveries =
                snap.docs
                    .map((doc) => DeliveryModel.fromFirestore(doc))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            pendingDeliveries.value = deliveries.take(5).toList();
          },
          onError: (Object error) {
            pendingDeliveries.value = [];
            errorMessage.value = 'Không thể cập nhật danh sách đơn giao hàng.';
          },
        );
  }

  /// Dừng lắng nghe đơn mới (khi offline hoặc đang bận chuyến)
  void _stopListeningOrders() {
    _ridesSub?.cancel();
    _ridesSub = null;
    _deliveriesSub?.cancel();
    _deliveriesSub = null;
    pendingRides.value = [];
    pendingDeliveries.value = [];
  }

  Future<void> refreshAvailableOrders({
    required LatLng center,
    required double radiusKm,
    required String filter,
  }) async {
    final requestId = ++_availableOrdersRequestId;
    isSearchingOrders.value = true;
    errorMessage.value = null;
    try {
      final ridesFuture = filter == 'delivery'
          ? null
          : _firestore
                .collection('rides')
                .where(
                  'status',
                  isEqualTo: RideStatus.pendingDriver.toFirestore(),
                )
                .limit(50)
                .get();
      final deliveriesFuture = filter == 'ride'
          ? null
          : _firestore
                .collection('deliveries')
                .where(
                  'status',
                  isEqualTo: DeliveryStatus.pendingDriver.toFirestore(),
                )
                .limit(50)
                .get();

      final rideDocs = ridesFuture == null
          ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
          : (await ridesFuture).docs;
      final deliveryDocs = deliveriesFuture == null
          ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
          : (await deliveriesFuture).docs;

      final distance = const Distance();
      bool isWithinRadius(double latitude, double longitude) {
        if (latitude == 0 || longitude == 0) return false;
        return distance.as(
              LengthUnit.Kilometer,
              center,
              LatLng(latitude, longitude),
            ) <=
            radiusKm;
      }

      final rides =
          rideDocs
              .map(RideModel.fromFirestore)
              .where((ride) => isWithinRadius(ride.pickupLat, ride.pickupLng))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final deliveries =
          deliveryDocs
              .map(DeliveryModel.fromFirestore)
              .where(
                (delivery) =>
                    isWithinRadius(delivery.pickupLat, delivery.pickupLng),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (requestId == _availableOrdersRequestId) {
        availableRides.value = rides;
        availableDeliveries.value = deliveries;
      }
    } catch (e) {
      if (requestId == _availableOrdersRequestId) {
        errorMessage.value = 'Không thể tìm đơn quanh bạn. Vui lòng thử lại.';
      }
    } finally {
      if (requestId == _availableOrdersRequestId) {
        isSearchingOrders.value = false;
      }
    }
  }

  // ── Toggle Online / Offline ───────────────────────────────────────────────

  /// Bật/tắt trạng thái nhận cuốc — cập nhật lên Firestore
  Future<void> toggleOnline({LatLng? currentPosition}) async {
    if (driverModel.value?.isBusy == true) {
      errorMessage.value =
          'Bạn đang thực hiện chuyến, không thể đổi trạng thái.';
      return;
    }

    if (_uid.isEmpty) {
      isOnline.value = !isOnline.value;
      return;
    }
    final newStatus = !isOnline.value;
    try {
      final Map<String, dynamic> updateData = {
        'isOnline': newStatus,
        'lastActiveAt': FieldValue.serverTimestamp(),
      };

      // Khi chuyển sang online → cập nhật geohash từ vị trí hiện tại trong model
      if (newStatus && currentPosition != null) {
        final lat = currentPosition.latitude;
        final lng = currentPosition.longitude;
        updateData['currentLat'] = lat;
        updateData['currentLng'] = lng;
        if (lat != 0.0 && lng != 0.0) {
          updateData['geohash'] = GeohashUtil.encode(lat, lng, precision: 6);
        }
      } else if (newStatus && driverModel.value != null) {
        final lat = driverModel.value!.currentLat;
        final lng = driverModel.value!.currentLng;
        if (lat != 0.0 && lng != 0.0) {
          updateData['geohash'] = GeohashUtil.encode(lat, lng, precision: 6);
        }
      }

      await _firestore.collection('drivers').doc(_uid).update(updateData);
      // isOnline.value sẽ tự cập nhật qua stream _driverSub
    } catch (e) {
      errorMessage.value = 'Không thể cập nhật trạng thái. Vui lòng thử lại.';
    }
  }

  // ── Nhận Cuốc Xe Ôm ───────────────────────────────────────────────────────

  /// Tài xế chấp nhận cuốc xe ôm
  Future<bool> acceptRide(RideModel ride) async {
    if (_uid.isEmpty || driverModel.value == null) return false;
    final driver = driverModel.value!;
    final user = userModel.value;

    // Kiểm tra tài xế không đang bận chuyến khác
    if (driver.isBusy) {
      errorMessage.value =
          'Bạn đang thực hiện chuyến khác, không thể nhận thêm.';
      return false;
    }

    try {
      final batch = _firestore.batch();
      final rideRef = _firestore.collection('rides').doc(ride.id);
      final driverRef = _firestore.collection('drivers').doc(_uid);

      // Cập nhật trạng thái cuốc xe
      batch.update(rideRef, {
        'status': RideStatus.accepted.toFirestore(),
        'driverId': _uid,
        'driverName': user?.fullName ?? driver.id,
        'driverPhone': user?.phone ?? '',
        'driverPlate': driver.plateNumber,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Đánh dấu tài xế đang bận
      batch.update(driverRef, {
        'isBusy': true,
        'activeTripId': ride.id,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      errorMessage.value = 'Không thể nhận cuốc. Vui lòng thử lại.';
      return false;
    }
  }

  // ── Nhận Đơn Giao Hàng ───────────────────────────────────────────────────

  /// Tài xế chấp nhận đơn giao hàng
  Future<bool> acceptDelivery(DeliveryModel delivery) async {
    if (_uid.isEmpty || driverModel.value == null) return false;
    final driver = driverModel.value!;
    final user = userModel.value;

    if (driver.isBusy) {
      errorMessage.value =
          'Bạn đang thực hiện chuyến khác, không thể nhận thêm.';
      return false;
    }

    try {
      final batch = _firestore.batch();
      final deliveryRef = _firestore.collection('deliveries').doc(delivery.id);
      final driverRef = _firestore.collection('drivers').doc(_uid);

      // Cập nhật trạng thái đơn giao
      batch.update(deliveryRef, {
        'status': DeliveryStatus.accepted.toFirestore(),
        'driverId': _uid,
        'driverName': user?.fullName ?? driver.id,
        'driverPhone': user?.phone ?? '',
        'driverPlate': driver.plateNumber,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Đánh dấu tài xế đang bận
      batch.update(driverRef, {
        'isBusy': true,
        'activeTripId': delivery.id,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      errorMessage.value = 'Không thể nhận đơn. Vui lòng thử lại.';
      return false;
    }
  }

  // ── Cập nhật GPS tài xế (gọi từ ngoài khi có vị trí mới) ────────────────

  /// Cập nhật tọa độ GPS hiện tại lên Firestore (gọi định kỳ)
  Future<void> updateLocation(double lat, double lng, double heading) async {
    if (_uid.isEmpty) return;
    try {
      await _firestore.collection('drivers').doc(_uid).update({
        'currentLat': lat,
        'currentLng': lng,
        'heading': heading,
        'geohash': GeohashUtil.encode(lat, lng, precision: 6),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Không thể đồng bộ vị trí tài xế: $error');
      errorMessage.value = 'Không thể đồng bộ vị trí tài xế. Vui lòng thử lại.';
    }
  }

  // ── Dọn dẹp tài nguyên khi widget bị dispose ─────────────────────────────
  void dispose() {
    _driverSub?.cancel();
    _ridesSub?.cancel();
    _deliveriesSub?.cancel();
    isLoading.dispose();
    driverModel.dispose();
    userModel.dispose();
    isOnline.dispose();
    pendingRides.dispose();
    pendingDeliveries.dispose();
    availableRides.dispose();
    availableDeliveries.dispose();
    isSearchingOrders.dispose();
    errorMessage.dispose();
  }
}
