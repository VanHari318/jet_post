import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../modules/admin/screens/admin_analytics_screen.dart';
import '../modules/admin/screens/admin_broadcast_screen.dart';
import '../modules/admin/screens/admin_dashboard_screen.dart';
import '../modules/admin/screens/admin_dispute_screen.dart';
import '../modules/admin/screens/admin_kyc_review_screen.dart';
import '../modules/admin/screens/admin_login_screen.dart';
import '../modules/admin/screens/admin_pricing_screen.dart';
import '../modules/admin/screens/admin_radar_screen.dart';
import '../modules/admin/screens/admin_user_management_screen.dart';
import '../modules/user/screens/app_settings_screen.dart';
import '../modules/user/screens/change_phone_screen.dart';
import '../modules/user/screens/direct_chat_screen.dart';
import '../modules/user/screens/driver_ekyc_screen.dart';
import '../modules/user/screens/kyc_pending_screen.dart';
import '../modules/user/screens/link_email_screen.dart';
import '../modules/user/screens/messages_inbox_screen.dart';
import '../modules/user/screens/phone_auth_screen.dart';
import '../modules/user/screens/user_profile_screen.dart';
import '../modules/user/screens/welcome_gate_screen.dart';
import '../modules/driver/screens/driver_dashboard_screen.dart';
import '../modules/driver/screens/driver_trip_screen.dart';
import '../modules/driver/screens/driver_income_screen.dart';

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
  static const String kycPending = '/user/kyc-pending';
  static const String userProfile = '/user/profile';
  static const String appSettings = '/user/settings';
  static const String messagesInbox = '/user/messages-inbox';
  static const String directChat = '/user/direct-chat';
  static const String changePhone = '/user/change-phone';
  static const String linkEmail = '/user/link-email';

  // [Phân hệ 4 - Thành viên 4] Quản trị Điều hành & Radar
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminRadarMap = '/admin/radar-map';
  static const String adminKycApproval = '/admin/kyc-approval';
  static const String adminUsersManagement = '/admin/users-management';
  static const String adminDisputeManagement = '/admin/dispute-management';
  static const String adminPricingConfig = '/admin/pricing-config';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminBroadcast = '/admin/broadcast';

  /// Đăng ký danh sách các routes cố định của ứng dụng
  static Map<String, WidgetBuilder> get routes => {
    welcomeGate: (context) => const WelcomeGateScreen(),
    phoneAuth: (context) => const PhoneAuthScreen(),
    driverKyc: (context) => const DriverEkycScreen(),
    kycPending: (context) => const KycPendingScreen(),
    userProfile: (context) => const UserProfileScreen(),
    appSettings: (context) => const AppSettingsScreen(),
    messagesInbox: (context) => const MessagesInboxScreen(),
    driverDashboard: (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return DriverDashboardScreen(
        suppressActiveTripRedirect:
            args?['suppressActiveTripRedirect'] as bool? ?? false,
      );
    },
    driverTrip: (context) => const DriverTripScreen(),
    driverIncome: (context) => const DriverIncomeScreen(),
    adminLogin: (context) => const AdminLoginScreen(),
    adminKycApproval: (context) => const AdminKycReviewScreen(),
    adminUsersManagement: (context) => const AdminUserManagementScreen(),
    adminDisputeManagement: (context) => const AdminDisputeScreen(),
    adminAnalytics: (context) => const AdminAnalyticsScreen(),
  };

  /// Bộ xử lý chuyển hướng động (onGenerateRoute)
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == adminDashboard) {
      final adminUser = _extractAdminUser(settings.arguments);
      if (adminUser == null) {
        return MaterialPageRoute(builder: (_) => const AdminLoginScreen());
      }
      return MaterialPageRoute(
        builder: (_) => AdminDashboardScreen(adminUser: adminUser),
      );
    }
    if (settings.name == adminRadarMap) {
      final adminUser = _extractAdminUser(settings.arguments);
      if (adminUser == null) {
        return MaterialPageRoute(builder: (_) => const AdminLoginScreen());
      }
      return MaterialPageRoute(
        builder: (_) => AdminRadarScreen(adminUser: adminUser),
      );
    }
    if (settings.name == adminPricingConfig) {
      final adminId = _extractAdminId(settings.arguments);
      return MaterialPageRoute(
        builder: (_) => AdminPricingScreen(adminId: adminId),
      );
    }
    if (settings.name == adminBroadcast) {
      final adminId = _extractAdminId(settings.arguments);
      return MaterialPageRoute(
        builder: (_) => AdminBroadcastScreen(adminId: adminId),
      );
    }
    if (settings.name == directChat) {
      final args = settings.arguments as Map<String, dynamic>? ?? {};
      return MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          chatId: args['chatId'] as String? ?? '',
          targetUserId: args['targetUserId'] as String? ?? '',
          targetName: args['targetName'] as String? ?? 'Người dùng',
          targetAvatar: args['targetAvatar'] as String?,
          targetPhone: args['targetPhone'] as String?,
        ),
      );
    }
    if (settings.name == changePhone) {
      final args = settings.arguments as Map<String, dynamic>? ?? {};
      return MaterialPageRoute(
        builder: (_) => ChangePhoneScreen(
          currentPhone: args['currentPhone'] as String? ?? '',
          linkedEmail: args['linkedEmail'] as String?,
        ),
      );
    }
    if (settings.name == linkEmail) {
      return MaterialPageRoute(builder: (_) => const LinkEmailScreen());
    }
    return null;
  }

  static UserModel? _extractAdminUser(Object? args) {
    if (args is UserModel) {
      return args;
    }
    if (args is Map<String, dynamic>) {
      final candidate = args['adminUser'];
      if (candidate is UserModel) {
        return candidate;
      }
    }
    return null;
  }

  static String _extractAdminId(Object? args) {
    if (args is String && args.isNotEmpty) {
      return args;
    }
    if (args is Map<String, dynamic>) {
      final candidate = args['adminId'];
      if (candidate is String && candidate.isNotEmpty) {
        return candidate;
      }
      final adminUser = args['adminUser'];
      if (adminUser is UserModel && adminUser.id.isNotEmpty) {
        return adminUser.id;
      }
    }
    return 'admin_demo_001';
  }

  /// Bộ xử lý chuyển hướng dự phòng nếu route không tồn tại
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy trang')),
        body: Center(child: Text('Trang ${settings.name} chưa được cấu hình!')),
      ),
    );
  }
}
