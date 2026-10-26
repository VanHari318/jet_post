import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_enums.dart';

/// Thực thể Dữ liệu Người dùng (Users Collection)
/// Đại diện cho tài khoản Khách hàng, Đối tác Tài xế hoặc Quản trị viên
/// Hỗ trợ Xác thực Đa kênh (Phone OTP + Email/Password)
class UserModel {
  final String id; // Firebase Auth UID
  final String phone; // Số điện thoại E.164 (+84...)
  final String? email; // Địa chỉ email đăng nhập / nhận OTP
  final String fullName; // Họ và tên đầy đủ
  final String? avatarUrl; // Đường dẫn ảnh đại diện trên Cloudinary
  final UserRole role; // Vai trò: customer | driver | admin
  final List<String> authProviders; // ['phone'], ['email'], hoặc ['phone', 'email']
  final bool isEmailVerified; // Cờ đã xác thực email chính chủ
  final bool isBanned; // Cờ khóa tài khoản vi phạm
  final DateTime createdAt; // Thời điểm tạo tài khoản
  final DateTime updatedAt; // Thời điểm cập nhật hồ sơ gần nhất

  UserModel({
    required this.id,
    required this.phone,
    this.email,
    required this.fullName,
    this.avatarUrl,
    this.role = UserRole.customer,
    this.authProviders = const ['phone'],
    this.isEmailVerified = false,
    this.isBanned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Chuyển đổi từ Cloud Firestore DocumentSnapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawProviders = data['authProviders'];
    List<String> providers = const ['phone'];
    if (rawProviders is List) {
      providers = rawProviders.map((e) => e.toString()).toList();
    } else if (data['phone'] != null && (data['phone'] as String).isNotEmpty) {
      providers = ['phone'];
    }

    return UserModel(
      id: doc.id,
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String?,
      fullName: data['fullName'] as String? ?? 'Người dùng',
      avatarUrl: data['avatarUrl'] as String?,
      role: UserRole.fromFirestore(data['role'] as String?),
      authProviders: providers,
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      isBanned: data['isBanned'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Chuyển đổi thành Map để ghi lên Cloud Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'phone': phone,
      'email': email,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'role': role.toFirestore(),
      'authProviders': authProviders,
      'isEmailVerified': isEmailVerified,
      'isBanned': isBanned,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? phone,
    String? email,
    String? fullName,
    String? avatarUrl,
    UserRole? role,
    List<String>? authProviders,
    bool? isEmailVerified,
    bool? isBanned,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      authProviders: authProviders ?? this.authProviders,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
