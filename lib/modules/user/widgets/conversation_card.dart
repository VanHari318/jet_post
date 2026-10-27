import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../models/conversation_model.dart';

/// Thẻ hiển thị một Cuộc trò chuyện trong Hộp thư (Conversation List Item)
class ConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const ConversationCard({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tìm UID của người đối thoại
    final otherUid = conversation.participants.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => '',
    );

    // Lấy thông tin người đối thoại từ participantDetails
    final otherDetails =
        conversation.participantDetails[otherUid] as Map<String, dynamic>? ?? {};
    final otherName = otherDetails['name'] as String? ?? 'Người dùng';
    final otherAvatar = otherDetails['avatar'] as String?;

    // Số tin nhắn chưa đọc của người dùng hiện tại
    final unread = conversation.unreadCount[currentUserId] ?? 0;
    final hasUnread = unread > 0;

    // Định dạng thời gian
    final now = DateTime.now();
    final updated = conversation.updatedAt;
    String timeStr;
    if (updated.year == now.year &&
        updated.month == now.month &&
        updated.day == now.day) {
      timeStr = DateFormat('HH:mm').format(updated);
    } else {
      timeStr = DateFormat('dd/MM').format(updated);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: hasUnread
              ? (isDark ? AppColors.primary.withAlpha(25) : const Color(0xFFF0FDF4))
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread
                ? AppColors.primary.withAlpha(70)
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: hasUnread ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Avatar người đối thoại (tối ưu hóa qua Cloudinary)
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withAlpha(30),
              backgroundImage: otherAvatar != null && otherAvatar.isNotEmpty
                  ? NetworkImage(
                      CloudinaryService.instance.getOptimizedUrl(
                        otherAvatar,
                        width: 100,
                        height: 100,
                      ),
                    )
                  : null,
              child: otherAvatar == null || otherAvatar.isEmpty
                  ? Text(
                      otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 12),

            // Thông tin hội thoại
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              hasUnread ? FontWeight.bold : FontWeight.normal,
                          color: hasUnread
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage.isNotEmpty
                              ? conversation.lastMessage
                              : 'Chưa có tin nhắn',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.normal,
                            color: hasUnread
                                ? (isDark
                                    ? AppColors.textPrimaryDark
                                    : Colors.black87)
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
