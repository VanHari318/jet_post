import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_logger.dart';
import '../../../models/message_model.dart';
import '../services/user_service.dart';
import '../widgets/chat_bubble.dart';

/// Màn hình Phòng Chat Trực Tiếp 1-1 (Direct 1-on-1 Chat Room Screen)
/// Lắng nghe Stream tin nhắn thời gian thực và gửi tin nhắn tức thời
class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String targetUserId;
  final String targetName;
  final String? targetAvatar;
  final String? targetPhone;

  const DirectChatScreen({
    super.key,
    required this.chatId,
    required this.targetUserId,
    required this.targetName,
    this.targetAvatar,
    this.targetPhone,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    AppLogger.navigation('DirectChat', 'DirectChatScreen', {
      'chatId': widget.chatId,
      'with': widget.targetName,
      'uid': widget.targetUserId,
    });
    // Đánh dấu đã đọc khi mở phòng chat
    UserService.instance.markConversationAsRead(widget.chatId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Gửi tin nhắn mới
  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (text.length > 2000) {
      AppDialogs.showError(
        context,
        title: 'Tin Nhắn Quá Dài',
        message: 'Nội dung tin nhắn không được vượt quá 2.000 ký tự!',
      );
      return;
    }

    AppLogger.userAction('DirectChat', 'Bấm gửi tin nhắn', {
      'to': widget.targetName,
      'content': text,
    });

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await UserService.instance.sendMessage(
        chatId: widget.chatId,
        receiverId: widget.targetUserId,
        content: text,
      );

      // Cuộn xuống tin nhắn mới nhất
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      AppLogger.error('DirectChat', 'Lỗi gửi tin nhắn', e);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // Gọi điện thoại trực tiếp
  Future<void> _handleCallPhone() async {
    AppLogger.userAction('DirectChat', 'Bấm Gọi điện thoại', {'targetPhone': widget.targetPhone});

    if (widget.targetPhone == null || widget.targetPhone!.isEmpty) {
      AppDialogs.showError(
        context,
        title: 'Không Có Số Điện Thoại',
        message: 'Người dùng này chưa cập nhật số điện thoại khả dụng để gọi.',
      );
      return;
    }

    final url = Uri.parse('tel:${widget.targetPhone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUid = FirebaseService.currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withAlpha(30),
              backgroundImage: widget.targetAvatar != null && widget.targetAvatar!.isNotEmpty
                  ? NetworkImage(
                      CloudinaryService.instance.getOptimizedUrl(
                        widget.targetAvatar!,
                        width: 80,
                        height: 80,
                      ),
                    )
                  : null,
              child: widget.targetAvatar == null || widget.targetAvatar!.isEmpty
                  ? Text(
                      widget.targetName.isNotEmpty ? widget.targetName[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.targetName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Trực tuyến P2P',
                    style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.targetPhone != null)
            IconButton(
              icon: const Icon(Icons.call, color: AppColors.primary),
              tooltip: 'Gọi điện thoại',
              onPressed: _handleCallPhone,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Luồng tin nhắn thời gian thực
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: UserService.instance.getMessagesStream(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.waving_hand,
                            size: 48,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Hãy gửi lời chào đến ${widget.targetName}!',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Tin mới nhất nằm ở dưới cùng
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == myUid;
                      return ChatBubble(message: msg, isMe: isMe);
                    },
                  );
                },
              ),
            ),

            // Khung soạn thảo tin nhắn ở đáy màn hình
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 4,
                        minLines: 1,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(2000),
                        ],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _handleSendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _handleSendMessage,
                    ),
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
