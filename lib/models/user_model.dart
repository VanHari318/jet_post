import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_enums.dart';

/// Thực thể Dữ liệu Người dùng (Users Collection)
/// Đại diện cho tài khoản Khách hàng, Đối tác Tài xế hoặc Quản trị viên
class UserModel {
  final String id; // Firebase Auth UID
  final String phone; // Số điện thoại E.164 (+84...)
  final String fullName; // Họ và tên đầy đủ
  final String? avatarUrl; // Đường dẫn ảnh đại diện trên Firebase Storage
  final UserRole role; // Vai trò: customer | driver | admin
  final bool isBanned; // Cờ khóa tài khoản vi phạm
  final DateTime createdAt; // Thời điểm tạo tài khoản
  final DateTime updatedAt; // Thời điểm cập nhật hồ sơ gần nhất

  UserModel({
    required this.id,
    required this.phone,
    required this.fullName,
    this.avatarUrl,
    this.role = UserRole.customer,
    this.isBanned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Chuyển đổi từ Cloud Firestore DocumentSnapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      phone: data['phone'] as String? ?? '',
      fullName: data['fullName'] as String? ?? 'Người dùng',
      avatarUrl: data['avatarUrl'] as String?,
      role: UserRole.fromFirestore(data['role'] as String?),
      isBanned: data['isBanned'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Chuyển đổi thành Map để ghi lên Cloud Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'phone': phone,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'role': role.toFirestore(),
      'isBanned': isBanned,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? phone,
    String? fullName,
    String? avatarUrl,
    UserRole? role,
    bool? isBanned,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
