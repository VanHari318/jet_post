import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../models/conversation_model.dart';
import '../../../routes/app_routes.dart';
import '../services/user_service.dart';

class OrderChatButton extends StatelessWidget {
  final String targetUserId;
  final String targetName;
  final String? targetPhone;
  final String? label;

  const OrderChatButton({
    super.key,
    required this.targetUserId,
    required this.targetName,
    this.targetPhone,
    this.label,
  });

  Future<void> _openChat(BuildContext context) async {
    if (targetUserId.isEmpty || targetUserId == FirebaseService.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể mở cuộc trò chuyện với người này.'),
        ),
      );
      return;
    }

    try {
      final chatId = await UserService.instance.getOrCreateConversation(
        targetUserId: targetUserId,
        targetName: targetName,
      );
      if (!context.mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.directChat,
        arguments: {
          'chatId': chatId,
          'targetUserId': targetUserId,
          'targetName': targetName,
          'targetPhone': targetPhone,
        },
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể mở tin nhắn: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseService.currentUserId ?? '';
    final ids = [uid, targetUserId]..sort();
    final chatId = '${ids[0]}_${ids[1]}';

    return StreamBuilder<List<ConversationModel>>(
      stream: UserService.instance.getConversationsStream(),
      builder: (context, snapshot) {
        final conversation = snapshot.data?.where((item) => item.id == chatId);
        final unreadCount = conversation?.isNotEmpty == true
            ? conversation!.first.unreadCount[uid] ?? 0
            : 0;
        final icon = _UnreadChatIcon(count: unreadCount);

        if (label == null) {
          return IconButton.filledTonal(
            onPressed: () => _openChat(context),
            tooltip: 'Nhắn tin',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: AppColors.primary,
            ),
            icon: icon,
          );
        }

        return ElevatedButton.icon(
          onPressed: () => _openChat(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          icon: icon,
          label: Text(
            label!,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

class _UnreadChatIcon extends StatelessWidget {
  final int count;

  const _UnreadChatIcon({required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 23,
      height: 23,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 2,
            bottom: 1,
            child: Icon(Icons.chat_bubble_outline, size: 19),
          ),
          if (count > 0)
            Positioned(
              right: -9,
              top: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
