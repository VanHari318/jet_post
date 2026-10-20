import 'package:flutter/material.dart';

/// Danh mục tên các đường dẫn (Route Names) toàn hệ thống JetPost
/// Phục vụ cơ chế điều phối Cổng vào (Welcome Gate) và phân quyền Role Guard
class AppRoutes {
  AppRoutes._();

  // Cổng vào hợp nhất (Entry Point Gate)
  static const String welcomeGate = '/';

  // [Phân hệ 1 - Thành viên 1] Khách hàng & Đặt cuốc
  static const String customerHome = '/customer/home';
  static const String rideBooking = '/customer/ride-booking';
  static const String deliveryBooking = '/customer/delivery-booking';
  static const String liveTracking = '/customer/live-tracking';
  static const String consigneeTracking = '/customer/consignee-tracking';
  static const String customerActivity = '/customer/activity';
  static const String savedAddresses = '/customer/saved-addresses';

  // [Phân hệ 2 - Thành viên 2 (Hải)] Đối tác Tài xế
  static const String driverDashboard = '/driver/dashboard';
  static const String driverTrip = '/driver/trip';
  static const String driverIncome = '/driver/income';

  // [Phân hệ 3 - Thành viên 3] User, Định danh & Chat
  static const String phoneAuth = '/user/phone-auth';
  static const String driverKyc = '/user/driver-ekyc';
  static const String userProfile = '/user/profile';
  static const String appSettings = '/user/settings';
  static const String messagesInbox = '/user/messages-inbox';
  static const String directChat = '/user/direct-chat';

  // [Phân hệ 4 - Thành viên 4] Quản trị Điều hành & Radar
  static const String adminDashboard = '/admin/dashboard';
  static const String adminRadarMap = '/admin/radar-map';
  static const String adminKycApproval = '/admin/kyc-approval';
  static const String adminUsersManagement = '/admin/users-management';
  static const String adminPricingConfig = '/admin/pricing-config';
  static const String adminAnalytics = '/admin/analytics';

  /// Bộ xử lý chuyển hướng dự phòng nếu route không tồn tại
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy trang')),
        body: Center(
          child: Text('Trang ${settings.name} chưa được cấu hình!'),
        ),
      ),
    );
  }
}
