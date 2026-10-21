import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';
import '../../../models/delivery_model.dart';
import '../../../models/ride_model.dart';
import '../../../models/system_settings_model.dart';
import '../../../models/system_notification_model.dart';
import '../../../core/constants/app_enums.dart';

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

  /// Stream toàn bộ tài xế (Online + Busy) - màu khác nhau trên radar
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

  /// Stream danh sách tài xế đang chờ duyệt hồ sơ
  Stream<List<DriverModel>> watchPendingDriverApprovals() {
    return _db
        .collection('drivers')
        .where('status', isEqualTo: 'PENDING_APPROVAL')
        .orderBy('lastActiveAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DriverModel.fromFirestore).toList());
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
      'lastActiveAt': FieldValue.serverTimestamp(),
    });

    // 2. Ghi log hành động admin (tùy chọn - audit trail)
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

  /// Stream danh sách người dùng có lọc theo role
  Stream<List<UserModel>> watchUsers({String? roleFilter}) {
    Query<Map<String, dynamic>> query = _db.collection('users');
    if (roleFilter != null && roleFilter.isNotEmpty) {
      query = query.where('role', isEqualTo: roleFilter);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  /// Tìm kiếm user theo tên hoặc số điện thoại
  Future<List<UserModel>> searchUsers(String keyword) async {
    // Tìm theo SĐT
    final byPhone = await _db
        .collection('users')
        .where('phone', isGreaterThanOrEqualTo: keyword)
        .where('phone', isLessThanOrEqualTo: '$keyword\uf8ff')
        .get();

    // Tìm theo tên
    final byName = await _db
        .collection('users')
        .where('fullName', isGreaterThanOrEqualTo: keyword)
        .where('fullName', isLessThanOrEqualTo: '$keyword\uf8ff')
        .get();

    final merged = <String, UserModel>{};
    for (final doc in [...byPhone.docs, ...byName.docs]) {
      merged[doc.id] = UserModel.fromFirestore(doc);
    }
    return merged.values.toList();
  }

  /// Lấy lịch sử cuốc xe của một người dùng (Customer)
  Future<List<RideModel>> getUserRideHistory(String customerId,
      {int limit = 20}) async {
    final snap = await _db
        .collection('rides')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(RideModel.fromFirestore).toList();
  }

  /// Lấy lịch sử cuốc của tài xế
  Future<List<RideModel>> getDriverRideHistory(String driverId,
      {int limit = 20}) async {
    final snap = await _db
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(RideModel.fromFirestore).toList();
  }

  /// KHÓA tài khoản (Ban) - tài khoản đó ngay lập tức không thể đăng nhập
  Future<void> banUser({
    required String userId,
    required String adminId,
    required String reason,
  }) async {
    final batch = _db.batch();

    batch.update(_db.collection('users').doc(userId), {
      'isBanned': true,
      'banReason': reason,
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

  /// Tra cứu đơn giao hàng theo mã để đối soát tranh chấp
  Future<DeliveryModel?> getDeliveryById(String deliveryId) async {
    final doc = await _db.collection('deliveries').doc(deliveryId).get();
    if (!doc.exists) return null;
    return DeliveryModel.fromFirestore(doc);
  }

  /// Tra cứu cuốc xe theo mã
  Future<RideModel?> getRideById(String rideId) async {
    final doc = await _db.collection('rides').doc(rideId).get();
    if (!doc.exists) return null;
    return RideModel.fromFirestore(doc);
  }

  /// Stream tất cả đơn COMPLETED hoặc CANCELLED để đối soát
  Stream<List<DeliveryModel>> watchDeliveriesForDispute({
    String? status,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('deliveries');
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(DeliveryModel.fromFirestore).toList());
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
        .map((doc) => doc.exists ? SystemSettingsModel.fromFirestore(doc) : null);
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
        totalRideRevenue += (data['systemFee'] as num?)?.toDouble() ?? 0;
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
        totalDeliveryRevenue += (data['systemFee'] as num?)?.toDouble() ?? 0;
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

  /// Lấy dữ liệu doanh thu theo từng ngày (cho biểu đồ đường)
  Future<List<DailyRevenueData>> getDailyRevenue({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromTs = Timestamp.fromDate(from);
    final toTs = Timestamp.fromDate(to);

    final ridesSnap = await _db
        .collection('rides')
        .where('status', isEqualTo: 'COMPLETED')
        .where('completedAt', isGreaterThanOrEqualTo: fromTs)
        .where('completedAt', isLessThanOrEqualTo: toTs)
        .get();

    final deliveriesSnap = await _db
        .collection('deliveries')
        .where('status', isEqualTo: 'COMPLETED')
        .where('deliveredAt', isGreaterThanOrEqualTo: fromTs)
        .where('deliveredAt', isLessThanOrEqualTo: toTs)
        .get();

    final Map<String, double> revenueByDay = {};

    for (final doc in ridesSnap.docs) {
      final data = doc.data();
      final ts = (data['completedAt'] as Timestamp?)?.toDate();
      if (ts != null) {
        final key = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
        revenueByDay[key] = (revenueByDay[key] ?? 0) +
            ((data['systemFee'] as num?)?.toDouble() ?? 0);
      }
    }

    for (final doc in deliveriesSnap.docs) {
      final data = doc.data();
      final ts = (data['deliveredAt'] as Timestamp?)?.toDate();
      if (ts != null) {
        final key = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
        revenueByDay[key] = (revenueByDay[key] ?? 0) +
            ((data['systemFee'] as num?)?.toDouble() ?? 0);
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
