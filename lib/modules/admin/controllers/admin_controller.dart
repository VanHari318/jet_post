import '../../../models/delivery_model.dart';
import '../../../models/driver_model.dart';
import '../../../models/ride_model.dart';
import '../../../models/system_notification_model.dart';
import '../../../models/system_settings_model.dart';
import '../../../models/user_model.dart';
import '../services/admin_service.dart';

class AdminController {
  static final AdminController _instance = AdminController._internal();
  factory AdminController() => _instance;
  AdminController._internal();

  final AdminService _service = AdminService();

  // Task 4.1
  Future<bool> isAdmin(String uid) => _service.isAdmin(uid);
  Future<UserModel?> getAdminProfile(String uid) =>
      _service.getAdminProfile(uid);
  Future<UserModel> ensureAdminProfile({
    required String uid,
    required String email,
  }) =>
      _service.ensureAdminProfile(uid: uid, email: email);

  // Task 4.2
  Stream<List<DriverModel>> watchAllOnlineDrivers() =>
      _service.watchAllOnlineDrivers();
  Stream<List<DriverModel>> watchAllActiveDrivers() =>
      _service.watchAllActiveDrivers();
  Future<DriverModel?> getDriverDetail(String driverId) =>
      _service.getDriverDetail(driverId);
  Future<UserModel?> getUserByDriverId(String driverId) =>
      _service.getUserByDriverId(driverId);

  // Task 4.3
  Stream<List<DriverModel>> watchPendingDriverApprovals() =>
      _service.watchPendingDriverApprovals();
  Future<void> approveDriver({
    required String driverId,
    required String adminId,
  }) =>
      _service.approveDriver(driverId: driverId, adminId: adminId);
  Future<void> rejectDriver({
    required String driverId,
    required String adminId,
    required String reason,
  }) =>
      _service.rejectDriver(
        driverId: driverId,
        adminId: adminId,
        reason: reason,
      );

  // Task 4.4
  Stream<List<UserModel>> watchUsers({String? roleFilter}) =>
      _service.watchUsers(roleFilter: roleFilter);
  Future<List<UserModel>> searchUsers(String keyword) =>
      _service.searchUsers(keyword);
  Future<List<RideModel>> getUserRideHistory(
    String customerId, {
    int limit = 20,
  }) =>
      _service.getUserRideHistory(customerId, limit: limit);
  Future<List<RideModel>> getDriverRideHistory(
    String driverId, {
    int limit = 20,
  }) =>
      _service.getDriverRideHistory(driverId, limit: limit);
  Future<void> banUser({
    required String userId,
    required String adminId,
    required String reason,
    String duration = 'PERMANENT',
  }) =>
      _service.banUser(
        userId: userId,
        adminId: adminId,
        reason: reason,
        duration: duration,
      );
  Future<void> unbanUser({
    required String userId,
    required String adminId,
  }) =>
      _service.unbanUser(userId: userId, adminId: adminId);

  // Task 4.5
  Future<DeliveryModel?> getDeliveryById(String deliveryId) =>
      _service.getDeliveryById(deliveryId);
  Future<RideModel?> getRideById(String rideId) =>
      _service.getRideById(rideId);
  Stream<List<DeliveryModel>> watchDeliveriesForDispute({
    String? status,
    int limit = 50,
  }) =>
      _service.watchDeliveriesForDispute(status: status, limit: limit);
  Future<void> resolveDispute({
    required String deliveryId,
    required String adminId,
    required String decision,
    required String note,
  }) =>
      _service.resolveDispute(
        deliveryId: deliveryId,
        adminId: adminId,
        decision: decision,
        note: note,
      );

  // Task 4.6
  Future<SystemSettingsModel?> getSystemSettings() =>
      _service.getSystemSettings();
  Stream<SystemSettingsModel?> watchSystemSettings() =>
      _service.watchSystemSettings();
  Future<void> saveSystemSettings({
    required SystemSettingsModel settings,
    required String adminId,
  }) =>
      _service.saveSystemSettings(settings: settings, adminId: adminId);

  // Task 4.7
  Future<AdminAnalyticsData> getAnalytics({
    required DateTime from,
    required DateTime to,
  }) =>
      _service.getAnalytics(from: from, to: to);
  Future<List<DailyRevenueData>> getDailyRevenue({
    required DateTime from,
    required DateTime to,
  }) =>
      _service.getDailyRevenue(from: from, to: to);

  // Task 4.8
  Future<void> broadcastNotification({
    required String title,
    required String body,
    required String targetGroup,
    required String priority,
    required String adminId,
    DateTime? expiresAt,
  }) =>
      _service.broadcastNotification(
        title: title,
        body: body,
        targetGroup: targetGroup,
        priority: priority,
        adminId: adminId,
        expiresAt: expiresAt,
      );
  Stream<List<SystemNotificationModel>> watchBroadcastHistory() =>
      _service.watchBroadcastHistory();

  // Demo Data Seeder
  Future<void> seedDemoAdminData(String adminId) =>
      _service.seedDemoAdminData(adminId);
}
