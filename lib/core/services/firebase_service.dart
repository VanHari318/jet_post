import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Dịch vụ trung tâm cung cấp điểm truy cập thống nhất tới Google Firebase
class FirebaseService {
  FirebaseService._();

  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static final FirebaseStorage storage = FirebaseStorage.instance;

  /// Lấy UID người dùng đang đăng nhập hiện tại
  static String? get currentUserId => auth.currentUser?.uid;

  /// Kiểm tra xem đã có phiên đăng nhập hợp lệ chưa
  static bool get isAuthenticated => auth.currentUser != null;

  /// Lấy số điện thoại của tài khoản đang đăng nhập
  static String? get currentUserPhone => auth.currentUser?.phoneNumber;

  // Tên các Root Collections theo Đặc tả CSDL JetPost
  static const String colUsers = 'users';
  static const String colDrivers = 'drivers';
  static const String colRides = 'rides';
  static const String colDeliveries = 'deliveries';
  static const String colConversations = 'conversations';
  static const String colSystemSettings = 'system_settings';
  static const String colSystemNotifications = 'system_notifications';

  // Tên các Sub-collections
  static const String subSavedAddresses = 'saved_addresses';
  static const String subMessages = 'messages';
}
