import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/validators.dart';
import '../../../models/conversation_model.dart';
import '../services/user_service.dart';
import '../widgets/conversation_card.dart';
import 'direct_chat_screen.dart';

/// Màn hình Hộp thư Hội thoại Thời gian thực (Messages Inbox Screen)
/// Lắng nghe Stream danh sách các cuộc trò chuyện P2P 1-1 của tài khoản hiện tại
class MessagesInboxScreen extends StatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _newPhoneController.dispose();
    super.dispose();
  }

  // Khởi tạo cuộc trò chuyện mới qua Số điện thoại
  void _showNewChatDialog() {
    AppLogger.userAction('Inbox', 'Mở popup Nhắn Tin Mới');
    _newPhoneController.clear();
    String? phoneError;
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Nhắn Tin Mới'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhập số điện thoại người dùng bạn muốn trò chuyện:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPhoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: 0988888888',
                  errorText: phoneError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.phone, size: 20),
                ),
                onChanged: (_) {
                  if (phoneError != null) {
                    setDialogState(() => phoneError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSearching ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSearching
                  ? null
                  : () async {
                      final rawPhone = _newPhoneController.text.trim();
                      final valErr = AppValidators.validatePhone(rawPhone);
                      if (valErr != null) {
                        setDialogState(() => phoneError = valErr);
                        return;
                      }

                      final formattedPhone = UserService.instance.formatToE164(rawPhone);
                      if (formattedPhone == FirebaseService.currentUserPhone) {
                        setDialogState(() => phoneError = 'Bạn không thể tự nhắn tin cho chính mình!');
                        return;
                      }

                      setDialogState(() {
                        isSearching = true;
                        phoneError = null;
                      });

                      AppLogger.userAction('Inbox', 'Tìm kiếm người dùng để chat', {'phone': formattedPhone});

                      try {
                        // Tìm tài khoản trên Firestore
                        final query = await FirebaseService.firestore
                            .collection(FirebaseService.colUsers)
                            .where('phone', isEqualTo: formattedPhone)
                            .limit(1)
                            .get();

                        if (!mounted) return;

                        if (query.docs.isEmpty) {
                          AppLogger.info('Inbox', 'Không tìm thấy tài khoản với SĐT: $formattedPhone');
                          setDialogState(() {
                            isSearching = false;
                            phoneError = 'Không tìm thấy tài khoản với số điện thoại này!';
                          });
                          return;
                        }

                        final targetDoc = query.docs.first;
                        final targetUid = targetDoc.id;
                        final targetName = targetDoc.data()['fullName'] as String? ?? 'Người dùng';
                        final targetAvatar = targetDoc.data()['avatarUrl'] as String?;

                        if (targetUid == FirebaseService.currentUserId) {
                          setDialogState(() {
                            isSearching = false;
                            phoneError = 'Bạn không thể tự nhắn tin cho chính mình!';
                          });
                          return;
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        AppLogger.chat('Khởi tạo cuộc hội thoại', {'with': targetName, 'uid': targetUid});

                        // Mở phòng chat
                        final chatId = await UserService.instance.getOrCreateConversation(
                          targetUserId: targetUid,
                          targetName: targetName,
                          targetAvatar: targetAvatar,
                        );

                        if (!mounted || !context.mounted) return;

                        AppLogger.navigation('Inbox', 'DirectChatScreen', {'chatId': chatId});
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DirectChatScreen(
                              chatId: chatId,
                              targetUserId: targetUid,
                              targetName: targetName,
                              targetAvatar: targetAvatar,
                              targetPhone: formattedPhone,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() {
                          isSearching = false;
                          phoneError = 'Lỗi tìm kiếm: $e';
                        });
                      }
                    },
              child: isSearching
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Bắt đầu Chat'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUid = FirebaseService.currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin Nhắn Trực Tiếp P2P'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Ô tìm kiếm hội thoại
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm cuộc trò chuyện...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : const Color(0xFFF1F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),

            // Danh sách hội thoại Real-time Stream
            Expanded(
              child: StreamBuilder<List<ConversationModel>>(
                stream: UserService.instance.getConversationsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Lỗi tải tin nhắn: ${snapshot.error}'),
                    );
                  }

                  final list = snapshot.data ?? [];

                  // Lọc theo từ khóa tìm kiếm
                  final filtered = list.where((conv) {
                    if (_searchQuery.isEmpty) return true;
                    final otherUid = conv.participants.firstWhere(
                      (id) => id != myUid,
                      orElse: () => '',
                    );
                    final details = conv.participantDetails[otherUid] as Map<String, dynamic>? ?? {};
                    final name = (details['name'] as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery) || conv.lastMessage.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 64,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Không tìm thấy cuộc trò chuyện nào!'
                                  : 'Chưa có cuộc trò chuyện nào',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Bấm nút dấu cộng bên dưới để bắt đầu nhắn tin với Khách hàng hoặc Đối tác Tài xế.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      final otherUid = conv.participants.firstWhere(
                        (id) => id != myUid,
                        orElse: () => '',
                      );
                      final details = conv.participantDetails[otherUid] as Map<String, dynamic>? ?? {};
                      final targetName = details['name'] as String? ?? 'Người dùng';
                      final targetAvatar = details['avatar'] as String?;

                      return ConversationCard(
                        conversation: conv,
                        currentUserId: myUid,
                        onTap: () {
                          AppLogger.userAction('Inbox', 'Mở cuộc hội thoại', {
                            'chatId': conv.id,
                            'targetName': targetName,
                            'otherUid': otherUid,
                          });
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DirectChatScreen(
                                chatId: conv.id,
                                targetUserId: otherUid,
                                targetName: targetName,
                                targetAvatar: targetAvatar,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewChatDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_comment, color: Colors.white),
        label: const Text('Tin Nhắn Mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
