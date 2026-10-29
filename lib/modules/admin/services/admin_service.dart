import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_enums.dart';
import '../../../models/delivery_model.dart';
import '../../../models/driver_model.dart';
import '../../../models/ride_model.dart';
import '../../../models/system_notification_model.dart';
import '../../../models/system_settings_model.dart';
import '../../../models/user_model.dart';

/// Service 4: Admin Dispatcher & Core Module
/// Phụ trách: Radar GPS toàn mạng, Duyệt eKYC, Quản lý User, Tranh chấp, Biểu cước, Thông báo
class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // TASK 4.1: Xác thực Quản trị viên & Điều hướng
  // ─────────────────────────────────────────────

  /// Kiểm tra tài khoản hiện tại có role == 'admin' không
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final user = UserModel.fromFirestore(doc);
      return user.role == UserRole.admin;
    } catch (_) {
      return false;
    }
  }

  /// Lấy thông tin Admin đang đăng nhập
  Future<UserModel?> getAdminProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Đảm bảo tài khoản Admin mẫu (admin@jetpost.vn) luôn có hồ sơ hợp lệ trên Firestore
  Future<UserModel> ensureAdminProfile({
    required String uid,
    required String email,
  }) async {
    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();
    final now = DateTime.now();

    if (!doc.exists) {
      final adminUser = UserModel(
        id: uid,
        phone: '+84900000000',
        email: email,
        fullName: 'Quản Trị Viên JetPost',
        role: UserRole.admin,
        authProviders: const ['email'],
        isEmailVerified: true,
        isBanned: false,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(adminUser.toFirestore());
      return adminUser;
    } else {
      final existing = UserModel.fromFirestore(doc);
      if (existing.role != UserRole.admin &&
          email.toLowerCase() == 'admin@jetpost.vn') {
        await docRef.update({
          'role': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return existing.copyWith(role: UserRole.admin, updatedAt: now);
      }
      return existing;
    }
  }

  // ─────────────────────────────────────────────
  // TASK 4.2: Radar Điều hành Thời gian thực
  // ─────────────────────────────────────────────

  /// Stream toàn bộ tài xế ONLINE để hiển thị trên bản đồ radar
  Stream<List<DriverModel>> watchAllOnlineDrivers() {
    return _db
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(DriverModel.fromFirestore).toList());
  }

  /// Stream toàn bộ tài xế đã kích hoạt (Online + Busy) - màu khác nhau trên radar
  Stream<List<DriverModel>> watchAllActiveDrivers() {
    return _db
        .collection('drivers')
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snap) => snap.docs.map(DriverModel.fromFirestore).toList());
  }

  /// Lấy thông tin chi tiết 1 tài xế khi Admin bấm vào marker trên radar
  Future<DriverModel?> getDriverDetail(String driverId) async {
    final doc = await _db.collection('drivers').doc(driverId).get();
    if (!doc.exists) return null;
    return DriverModel.fromFirestore(doc);
  }

  /// Lấy thông tin User tương ứng với Driver ID
  Future<UserModel?> getUserByDriverId(String driverId) async {
    final doc = await _db.collection('users').doc(driverId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // ─────────────────────────────────────────────
  // TASK 4.3: Thẩm định & Phê duyệt eKYC
  // ─────────────────────────────────────────────

  /// Stream danh sách tài xế đang chờ duyệt hồ sơ (Sort in-memory tránh lỗi Composite Index)
  Stream<List<DriverModel>> watchPendingDriverApprovals() {
    return _db
        .collection('drivers')
        .where('status', isEqualTo: 'PENDING_APPROVAL')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(DriverModel.fromFirestore).toList();
      list.sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
      return list;
    });
  }

  /// Admin PHÊ DUYỆT hồ sơ tài xế → Kích hoạt tài khoản ACTIVE
  Future<void> approveDriver({
    required String driverId,
    required String adminId,
  }) async {
    final batch = _db.batch();

    // 1. Cập nhật trạng thái drivers collection
    final driverRef = _db.collection('drivers').doc(driverId);
    batch.update(driverRef, {
      'status': 'ACTIVE',
      'rejectionReason': FieldValue.delete(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });

    // 2. Đồng bộ role == 'driver' trên users collection
    final userRef = _db.collection('users').doc(driverId);
    batch.set(
      userRef,
      {
        'role': 'driver',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 3. Ghi log hành động admin (audit trail)
    final auditRef = _db.collection('admin_audit_logs').doc();
    batch.set(auditRef, {
      'action': 'APPROVE_DRIVER',
      'targetId': driverId,
      'adminId': adminId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Admin TỪ CHỐI hồ sơ tài xế kèm lý do
  Future<void> rejectDriver({
    required String driverId,
    required String adminId,
    required String reason,
  }) async {
    final batch = _db.batch();

    final driverRef = _db.collection('drivers').doc(driverId);
    batch.update(driverRef, {
      'status': 'REJECTED',
      'rejectionReason': reason,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });

    // Ghi log từ chối
    final auditRef = _db.collection('admin_audit_logs').doc();
    batch.set(auditRef, {
      'action': 'REJECT_DRIVER',
      'targetId': driverId,
      'adminId': adminId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // TASK 4.4: Quản lý Tài khoản & Thực thi Chế tài
  // ─────────────────────────────────────────────

  /// Stream danh sách người dùng có lọc theo role (Sort in-memory tránh lỗi Composite Index)
  Stream<List<UserModel>> watchUsers({String? roleFilter}) {
    Query<Map<String, dynamic>> query = _db.collection('users');
    if (roleFilter != null && roleFilter.isNotEmpty) {
      query = query.where('role', isEqualTo: roleFilter);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map(UserModel.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Tìm kiếm user theo tên hoặc số điện thoại
  Future<List<UserModel>> searchUsers(String keyword) async {
    final cleanKeyword = keyword.trim().toLowerCase();
    final snap = await _db.collection('users').limit(100).get();
    final results = <UserModel>[];

    for (final doc in snap.docs) {
      final user = UserModel.fromFirestore(doc);
      final matchName = user.fullName.toLowerCase().contains(cleanKeyword);
      final matchPhone = user.phone.toLowerCase().contains(cleanKeyword);
      final matchEmail =
          (user.email ?? '').toLowerCase().contains(cleanKeyword);
      if (matchName || matchPhone || matchEmail) {
        results.add(user);
      }
    }
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  /// Lấy lịch sử cuốc xe của một người dùng (Customer)
  Future<List<RideModel>> getUserRideHistory(
    String customerId, {
    int limit = 20,
  }) async {
    final snap = await _db
        .collection('rides')
        .where('customerId', isEqualTo: customerId)
        .get();
    final list = snap.docs.map(RideModel.fromFirestore).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  /// Lấy lịch sử cuốc của tài xế
  Future<List<RideModel>> getDriverRideHistory(
    String driverId, {
    int limit = 20,
  }) async {
    final snap = await _db
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .get();
    final list = snap.docs.map(RideModel.fromFirestore).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  /// KHÓA tài khoản (Ban) kèm thời hạn hoặc vĩnh viễn
  Future<void> banUser({
    required String userId,
    required String adminId,
    required String reason,
    String duration = 'PERMANENT',
  }) async {
    final batch = _db.batch();

    DateTime? banUntil;
    final now = DateTime.now();
    if (duration == '24H') {
      banUntil = now.add(const Duration(hours: 24));
    } else if (duration == '7D') {
      banUntil = now.add(const Duration(days: 7));
    } else if (duration == '30D') {
      banUntil = now.add(const Duration(days: 30));
    }

    batch.update(_db.collection('users').doc(userId), {
      'isBanned': true,
      'banReason': reason,
      'banDuration': duration,
      'banUntil': banUntil != null ? Timestamp.fromDate(banUntil) : null,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Nếu user là tài xế → cũng cập nhật drivers collection
    final driverDoc = await _db.collection('drivers').doc(userId).get();
    if (driverDoc.exists) {
      batch.update(_db.collection('drivers').doc(userId), {
        'status': 'BANNED',
        'isOnline': false,
      });
    }

    final auditRef = _db.collection('admin_audit_logs').doc();
    batch.set(auditRef, {
      'action': 'BAN_USER',
      'targetId': userId,
      'adminId': adminId,
      'reason': reason,
      'duration': duration,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// MỞ KHÓA tài khoản (Unban)
  Future<void> unbanUser({
    required String userId,
    required String adminId,
  }) async {
    final batch = _db.batch();

    batch.update(_db.collection('users').doc(userId), {
      'isBanned': false,
      'banReason': null,
      'banDuration': null,
      'banUntil': null,
      'bannedAt': null,
      'bannedBy': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Nếu là tài xế → khôi phục ACTIVE
    final driverDoc = await _db.collection('drivers').doc(userId).get();
    if (driverDoc.exists) {
      batch.update(_db.collection('drivers').doc(userId), {
        'status': 'ACTIVE',
      });
    }

    final auditRef = _db.collection('admin_audit_logs').doc();
    batch.set(auditRef, {
      'action': 'UNBAN_USER',
      'targetId': userId,
      'adminId': adminId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // TASK 4.5: Quản lý Tranh chấp & Đối soát PoD
  // ─────────────────────────────────────────────

  /// Tra cứu đơn giao hàng theo mã (hỗ trợ tìm chính xác hoặc tìm một phần mã đơn / SĐT)
  Future<DeliveryModel?> getDeliveryById(String deliveryId) async {
    final cleanId = deliveryId.trim();
    final doc = await _db.collection('deliveries').doc(cleanId).get();
    if (doc.exists) {
      return DeliveryModel.fromFirestore(doc);
    }
    // Hỗ trợ tìm kiếm theo tiền tố mã đơn hoặc SĐT người gửi/nhận
    final recentSnap = await _db.collection('deliveries').limit(100).get();
    for (final d in recentSnap.docs) {
      final model = DeliveryModel.fromFirestore(d);
      if (d.id.toLowerCase().contains(cleanId.toLowerCase()) ||
          model.senderPhone.contains(cleanId) ||
          model.receiverPhone.contains(cleanId)) {
        return model;
      }
    }
    return null;
  }

  /// Tra cứu cuốc xe theo mã
  Future<RideModel?> getRideById(String rideId) async {
    final doc = await _db.collection('rides').doc(rideId.trim()).get();
    if (!doc.exists) return null;
    return RideModel.fromFirestore(doc);
  }

  /// Stream tất cả đơn hàng để đối soát (Sort in-memory tránh lỗi Composite Index)
  Stream<List<DeliveryModel>> watchDeliveriesForDispute({
    String? status,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('deliveries');
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map(DeliveryModel.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    });
  }

  /// Admin ghi nhận quyết định phân xử tranh chấp đơn hàng
  Future<void> resolveDispute({
    required String deliveryId,
    required String adminId,
    required String decision,
    required String note,
  }) async {
    final batch = _db.batch();
    final deliveryRef = _db.collection('deliveries').doc(deliveryId);

    batch.set(
      deliveryRef,
      {
        'disputeDecision': decision,
        'disputeNote': note,
        'disputeResolvedBy': adminId,
        'disputeResolvedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final auditRef = _db.collection('admin_audit_logs').doc();
    batch.set(auditRef, {
      'action': 'RESOLVE_DISPUTE',
      'targetId': deliveryId,
      'adminId': adminId,
      'decision': decision,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // TASK 4.6: Cấu hình Biểu cước & Chính sách Hệ thống
  // ─────────────────────────────────────────────

  /// Lấy cấu hình biểu cước hiện tại từ Firestore
  Future<SystemSettingsModel?> getSystemSettings() async {
    final doc =
        await _db.collection('system_settings').doc('global_config').get();
    if (!doc.exists) return null;
    return SystemSettingsModel.fromFirestore(doc);
  }

  /// Stream cấu hình biểu cước - cập nhật realtime cho UI
  Stream<SystemSettingsModel?> watchSystemSettings() {
    return _db
        .collection('system_settings')
        .doc('global_config')
        .snapshots()
        .map((doc) =>
            doc.exists ? SystemSettingsModel.fromFirestore(doc) : null);
  }

  /// Admin lưu cấu hình biểu cước mới - tất cả client tự cập nhật
  Future<void> saveSystemSettings({
    required SystemSettingsModel settings,
    required String adminId,
  }) async {
    final data = settings.toFirestore();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedBy'] = adminId;

    await _db
        .collection('system_settings')
        .doc('global_config')
        .set(data, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────
  // TASK 4.7: Báo cáo Thống kê & Phân tích Kinh doanh
  // ─────────────────────────────────────────────

  /// Thống kê tổng hợp trong khoảng thời gian (Dashboard Overview)
  Future<AdminAnalyticsData> getAnalytics({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromTs = Timestamp.fromDate(from);
    final toTs = Timestamp.fromDate(to);

    // Đếm cuốc xe theo trạng thái
    final ridesSnap = await _db
        .collection('rides')
        .where('createdAt', isGreaterThanOrEqualTo: fromTs)
        .where('createdAt', isLessThanOrEqualTo: toTs)
        .get();

    // Đếm đơn giao hàng theo trạng thái
    final deliveriesSnap = await _db
        .collection('deliveries')
        .where('createdAt', isGreaterThanOrEqualTo: fromTs)
        .where('createdAt', isLessThanOrEqualTo: toTs)
        .get();

    // Đếm người dùng mới đăng ký
    final newUsersSnap = await _db
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: fromTs)
        .where('createdAt', isLessThanOrEqualTo: toTs)
        .get();

    // Đếm tài xế đang hoạt động
    final activeDriversSnap = await _db
        .collection('drivers')
        .where('status', isEqualTo: 'ACTIVE')
        .get();

    int totalRides = ridesSnap.docs.length;
    int completedRides = 0;
    int cancelledRides = 0;
    double totalRideRevenue = 0;

    for (final doc in ridesSnap.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? '';
      if (status == 'COMPLETED') {
        completedRides++;
        final fee = (data['systemFee'] as num?)?.toDouble();
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        totalRideRevenue += (fee != null && fee > 0) ? fee : (price * 0.15);
      } else if (status == 'CANCELLED') {
        cancelledRides++;
      }
    }

    int totalDeliveries = deliveriesSnap.docs.length;
    int completedDeliveries = 0;
    int cancelledDeliveries = 0;
    double totalDeliveryRevenue = 0;

    for (final doc in deliveriesSnap.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? '';
      if (status == 'COMPLETED') {
        completedDeliveries++;
        final fee = (data['systemFee'] as num?)?.toDouble();
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        totalDeliveryRevenue += (fee != null && fee > 0) ? fee : (price * 0.15);
      } else if (status == 'CANCELLED') {
        cancelledDeliveries++;
      }
    }

    return AdminAnalyticsData(
      totalRides: totalRides,
      completedRides: completedRides,
      cancelledRides: cancelledRides,
      totalRideRevenue: totalRideRevenue,
      totalDeliveries: totalDeliveries,
      completedDeliveries: completedDeliveries,
      cancelledDeliveries: cancelledDeliveries,
      totalDeliveryRevenue: totalDeliveryRevenue,
      newUsers: newUsersSnap.docs.length,
      activeDrivers: activeDriversSnap.docs.length,
    );
  }

  /// Lấy dữ liệu doanh thu theo từng ngày (cho biểu đồ đường - lọc in-memory tránh lỗi Index)
  Future<List<DailyRevenueData>> getDailyRevenue({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromTs = Timestamp.fromDate(from);
    final toTs = Timestamp.fromDate(to);

    final ridesSnap = await _db
        .collection('rides')
        .where('createdAt', isGreaterThanOrEqualTo: fromTs)
        .where('createdAt', isLessThanOrEqualTo: toTs)
        .get();

    final deliveriesSnap = await _db
        .collection('deliveries')
        .where('createdAt', isGreaterThanOrEqualTo: fromTs)
        .where('createdAt', isLessThanOrEqualTo: toTs)
        .get();

    final Map<String, double> revenueByDay = {};

    for (final doc in ridesSnap.docs) {
      final data = doc.data();
      if ((data['status'] as String? ?? '') != 'COMPLETED') continue;
      final ts = ((data['completedAt'] ?? data['createdAt']) as Timestamp?)
          ?.toDate();
      if (ts != null) {
        final key =
            '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
        final fee = (data['systemFee'] as num?)?.toDouble();
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        final rev = (fee != null && fee > 0) ? fee : (price * 0.15);
        revenueByDay[key] = (revenueByDay[key] ?? 0) + rev;
      }
    }

    for (final doc in deliveriesSnap.docs) {
      final data = doc.data();
      if ((data['status'] as String? ?? '') != 'COMPLETED') continue;
      final ts = ((data['deliveredAt'] ?? data['createdAt']) as Timestamp?)
          ?.toDate();
      if (ts != null) {
        final key =
            '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
        final fee = (data['systemFee'] as num?)?.toDouble();
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        final rev = (fee != null && fee > 0) ? fee : (price * 0.15);
        revenueByDay[key] = (revenueByDay[key] ?? 0) + rev;
      }
    }

    final result = revenueByDay.entries
        .map((e) => DailyRevenueData(date: e.key, revenue: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return result;
  }

  // ─────────────────────────────────────────────
  // TASK 4.8: Phát Thông báo & Cảnh báo Toàn hệ thống
  // ─────────────────────────────────────────────

  /// Admin phát thông báo broadcast tới toàn mạng lưới
  Future<void> broadcastNotification({
    required String title,
    required String body,
    required String targetGroup, // 'ALL' | 'DRIVERS' | 'CUSTOMERS'
    required String priority, // 'NORMAL' | 'HIGH' | 'URGENT'
    required String adminId,
    DateTime? expiresAt,
  }) async {
    await _db.collection('system_notifications').add({
      'title': title,
      'body': body,
      'targetGroup': targetGroup,
      'priority': priority,
      'createdBy': adminId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
    });
  }

  /// Stream lịch sử thông báo đã phát
  Stream<List<SystemNotificationModel>> watchBroadcastHistory() {
    return _db
        .collection('system_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map(SystemNotificationModel.fromFirestore).toList());
  }

  /// Khởi tạo dữ liệu mẫu phục vụ Demo trước Hội đồng (Radar, KYC, Đơn hàng)
  Future<void> seedDemoAdminData(String adminId) async {
    final batch = _db.batch();
    final now = DateTime.now();

    // 1. Tài xế đang Online sẵn sàng trên Radar (Xanh)
    final drv1Ref = _db.collection('drivers').doc('demo_driver_online_01');
    batch.set(
      drv1Ref,
      {
        'vehicleType': 'Honda Wave Alpha',
        'plateNumber': '29E2-688.88',
        'status': 'ACTIVE',
        'isOnline': true,
        'isBusy': false,
        'currentLat': 21.0074,
        'currentLng': 105.8247, // Khu vực ĐH Thủy Lợi - Tây Sơn
        'geohash': 'w7er8k',
        'heading': 45.0,
        'rating': 4.9,
        'totalReviews': 128,
        'totalTrips': 152,
        'walletBalance': 850000.0,
        'lastActiveAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('users').doc('demo_driver_online_01'),
      {
        'phone': '+84966666666',
        'email': 'taixe1@jetpost.vn',
        'fullName': 'Nguyễn Văn Hải (Tài xế)',
        'role': 'driver',
        'authProviders': ['phone'],
        'isEmailVerified': true,
        'isBanned': false,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    // 2. Tài xế đang bận chở khách / giao hàng trên Radar (Đỏ)
    final drv2Ref = _db.collection('drivers').doc('demo_driver_busy_02');
    batch.set(
      drv2Ref,
      {
        'vehicleType': 'Yamaha Exciter 150',
        'plateNumber': '29D1-456.78',
        'status': 'ACTIVE',
        'isOnline': true,
        'isBusy': true,
        'activeTripId': 'DEL_DEMO_9901',
        'currentLat': 21.0125,
        'currentLng': 105.8195, // Khu vực Láng Hạ / Thái Hà
        'geohash': 'w7er8m',
        'heading': 130.0,
        'rating': 4.8,
        'totalReviews': 84,
        'totalTrips': 96,
        'walletBalance': 520000.0,
        'lastActiveAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('users').doc('demo_driver_busy_02'),
      {
        'phone': '+84912345678',
        'email': 'taixe2@jetpost.vn',
        'fullName': 'Trần Minh Tuấn (Tài xế)',
        'role': 'driver',
        'authProviders': ['phone'],
        'isEmailVerified': true,
        'isBanned': false,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    // 3. Tài xế đang chờ duyệt eKYC (PENDING_APPROVAL)
    final drvKycRef = _db.collection('drivers').doc('demo_driver_kyc_03');
    batch.set(
      drvKycRef,
      {
        'vehicleType': 'Honda Vision 2024',
        'plateNumber': '29B1-999.14',
        'idCardFrontUrl':
            'https://res.cloudinary.com/demo/image/upload/v1312461204/sample.jpg',
        'idCardBackUrl':
            'https://res.cloudinary.com/demo/image/upload/v1312461204/sample.jpg',
        'licenseUrl':
            'https://res.cloudinary.com/demo/image/upload/v1312461204/sample.jpg',
        'status': 'PENDING_APPROVAL',
        'isOnline': false,
        'isBusy': false,
        'currentLat': 21.0050,
        'currentLng': 105.8280,
        'geohash': 'w7er8j',
        'heading': 0.0,
        'rating': 5.0,
        'totalReviews': 0,
        'totalTrips': 0,
        'walletBalance': 0.0,
        'lastActiveAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('users').doc('demo_driver_kyc_03'),
      {
        'phone': '+84977777777',
        'email': 'ungvien@jetpost.vn',
        'fullName': 'Lê Hoàng Nam (Ứng viên eKYC)',
        'role': 'driver',
        'authProviders': ['phone'],
        'isEmailVerified': false,
        'isBanned': false,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    // 4. Đơn giao hàng mẫu có PoD & OTP để đối soát tranh chấp
    final delRef = _db.collection('deliveries').doc('DEL_DEMO_9901');
    batch.set(
      delRef,
      {
        'senderId': 'demo_customer_01',
        'senderName': 'Phạm Thu Hà',
        'senderPhone': '+84988888888',
        'receiverName': 'Hoàng Quốc Việt',
        'receiverPhone': '0987654321',
        'packageType': 'DOCUMENT',
        'packageNote': 'Hồ sơ đồ án Nhóm 14 - Giao tận tay, gọi trước 5 phút',
        'driverId': 'demo_driver_busy_02',
        'driverName': 'Trần Minh Tuấn',
        'driverPhone': '+84912345678',
        'driverPlate': '29D1-456.78',
        'pickupAddress': '175 Tây Sơn, Đống Đa, Hà Nội (ĐH Thủy Lợi)',
        'pickupLat': 21.0074,
        'pickupLng': 105.8247,
        'dropoffAddress': '88 Láng Hạ, Đống Đa, Hà Nội',
        'dropoffLat': 21.0145,
        'dropoffLng': 105.8165,
        'pickupGeohash': 'w7er8k',
        'distanceKm': 3.5,
        'price': 28500.0,
        'systemFee': 4275.0,
        'driverIncome': 24225.0,
        'paymentMethod': 'CASH',
        'handoverOtp': '6824',
        'podPhotoUrl':
            'https://res.cloudinary.com/demo/image/upload/v1312461204/sample.jpg',
        'status': 'COMPLETED',
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        'acceptedAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 2, minutes: 55))),
        'deliveredAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 2, minutes: 30))),
      },
      SetOptions(merge: true),
    );

    // 5. Cuốc xe ôm mẫu hoàn thành cho báo cáo doanh thu
    final rideRef = _db.collection('rides').doc('RIDE_DEMO_8801');
    batch.set(
      rideRef,
      {
        'customerId': 'demo_customer_01',
        'customerName': 'Phạm Thu Hà',
        'customerPhone': '+84988888888',
        'driverId': 'demo_driver_online_01',
        'driverName': 'Nguyễn Văn Hải',
        'driverPhone': '+84966666666',
        'driverPlate': '29E2-688.88',
        'pickupAddress': '175 Tây Sơn, Đống Đa, Hà Nội',
        'pickupLat': 21.0074,
        'pickupLng': 105.8247,
        'dropoffAddress': '72 Nguyễn Trãi, Thanh Xuân, Hà Nội (Royal City)',
        'dropoffLat': 21.0028,
        'dropoffLng': 105.8152,
        'pickupGeohash': 'w7er8k',
        'distanceKm': 2.8,
        'price': 21400.0,
        'systemFee': 3210.0,
        'driverIncome': 18190.0,
        'paymentMethod': 'CASH',
        'status': 'COMPLETED',
        'rating': 5,
        'reviewComment': 'Tài xế chạy cẩn thận, đúng giờ!',
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 5))),
        'acceptedAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 4, minutes: 58))),
        'completedAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 4, minutes: 40))),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}

// ─────────────────────────────────────────────
// Data Classes cho Analytics (Task 4.7)
// ─────────────────────────────────────────────

class AdminAnalyticsData {
  final int totalRides;
  final int completedRides;
  final int cancelledRides;
  final double totalRideRevenue;
  final int totalDeliveries;
  final int completedDeliveries;
  final int cancelledDeliveries;
  final double totalDeliveryRevenue;
  final int newUsers;
  final int activeDrivers;

  const AdminAnalyticsData({
    required this.totalRides,
    required this.completedRides,
    required this.cancelledRides,
    required this.totalRideRevenue,
    required this.totalDeliveries,
    required this.completedDeliveries,
    required this.cancelledDeliveries,
    required this.totalDeliveryRevenue,
    required this.newUsers,
    required this.activeDrivers,
  });

  double get totalRevenue => totalRideRevenue + totalDeliveryRevenue;
  int get totalOrders => totalRides + totalDeliveries;
  int get completedOrders => completedRides + completedDeliveries;
  int get cancelledOrders => cancelledRides + cancelledDeliveries;

  double get completionRate =>
      totalOrders == 0 ? 0 : completedOrders / totalOrders * 100;
}

class DailyRevenueData {
  final String date; // 'YYYY-MM-DD'
  final double revenue;

  const DailyRevenueData({required this.date, required this.revenue});
}
