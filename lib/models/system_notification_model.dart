import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_enums.dart';

/// Thực thể Dữ liệu Thông Báo Phát Sóng (System Notifications Collection)
/// Quản trị viên Admin phát cảnh báo thời tiết, sự cố vận hành cho toàn hệ thống
class SystemNotificationModel {
  final String id; // Mã thông báo Auto ID
  final String title; // Tiêu đề thông báo
  final String body; // Nội dung hướng dẫn vận hành
  final String targetGroup; // ALL | DRIVERS | CUSTOMERS
  final NotificationPriority priority; // NORMAL | HIGH | URGENT
  final String createdBy; // UID quản trị viên phát sóng
  final DateTime createdAt; // Thời điểm phát thông báo
  final DateTime? expiresAt; // Thời điểm hết hạn hiển thị

  SystemNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.targetGroup = 'ALL',
    this.priority = NotificationPriority.normal,
    required this.createdBy,
    required this.createdAt,
    this.expiresAt,
  });

  factory SystemNotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SystemNotificationModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      targetGroup: data['targetGroup'] as String? ?? 'ALL',
      priority: NotificationPriority.fromFirestore(data['priority'] as String?),
      createdBy: data['createdBy'] as String? ?? 'system_admin',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'targetGroup': targetGroup,
      'priority': priority.toFirestore(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }
}
