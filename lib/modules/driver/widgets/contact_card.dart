import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../routes/app_routes.dart';
import '../../user/widgets/order_chat_button.dart';

/// Card hiển thị thông tin liên lạc
/// - Xe Ôm: 1 liên lạc (khách hàng)
/// - Giao Hàng: 2 liên lạc (người gửi + người nhận)
class ContactCard extends StatelessWidget {
  /// true = đơn giao hàng, false = xe ôm
  final bool isDelivery;

  /// UID tài xế hiện tại
  final String driverUid;

  // ── Thông tin xe ôm ──────────────────────────────────────────────────────
  final String? customerId;
  final String? customerName;
  final String? customerPhone;

  // ── Thông tin giao hàng ───────────────────────────────────────────────────
  final String? senderId;
  final String? senderName;
  final String? senderPhone;
  final String? receiverName;
  final String? receiverPhone;

  const ContactCard.ride({
    super.key,
    required this.driverUid,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
  }) : isDelivery = false,
       senderId = null,
       senderName = null,
       senderPhone = null,
       receiverName = null,
       receiverPhone = null;

  const ContactCard.delivery({
    super.key,
    required this.driverUid,
    this.senderId,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
  }) : isDelivery = true,
       customerId = null,
       customerName = null,
       customerPhone = null;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.contact_phone_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Thông Tin Liên Lạc',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            if (!isDelivery) ...[
              // ── Xe Ôm: chỉ hiện khách hàng ─────────────────────────────
              _ContactRow(
                role: 'Khách Hàng',
                name: customerName ?? '',
                phone: customerPhone ?? '',
                targetUserId: customerId,
                driverUid: driverUid,
                roleColor: AppColors.primary,
                roleIcon: Icons.person_rounded,
              ),
            ] else ...[
              // ── Giao Hàng: người gửi + người nhận ──────────────────────
              _ContactRow(
                role: 'Người Gửi',
                name: senderName ?? '',
                phone: senderPhone ?? '',
                targetUserId: senderId,
                driverUid: driverUid,
                roleColor: AppColors.secondary,
                roleIcon: Icons.upload_rounded,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _ContactRow(
                role: 'Người Nhận',
                name: receiverName ?? '',
                phone: receiverPhone ?? '',
                targetUserId: null, // Sẽ tra cứu tài khoản theo số điện thoại
                driverUid: driverUid,
                roleColor: AppColors.accent,
                roleIcon: Icons.download_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Row liên lạc cho một người — tên + SĐT + nút chat P2P + nút gọi + nút sao chép
class _ContactRow extends StatelessWidget {
  final String role;
  final String name;
  final String phone;
  final String? targetUserId;
  final String driverUid;
  final Color roleColor;
  final IconData roleIcon;

  const _ContactRow({
    required this.role,
    required this.name,
    required this.phone,
    this.targetUserId,
    required this.driverUid,
    required this.roleColor,
    required this.roleIcon,
  });

  /// Gọi điện bằng url_launcher
  Future<void> _callPhone(BuildContext context) async {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể thực hiện cuộc gọi')),
        );
      }
    }
  }

  /// Sao chép SĐT vào clipboard
  void _copyPhone(BuildContext context) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép: $phone'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Mở phòng chat P2P
  Future<void> _openChat(BuildContext context) async {
    if (driverUid.isEmpty) {
      AppDialogs.showWarning(
        context,
        title: 'Chưa Đăng Nhập',
        message: 'Vui lòng đăng nhập tài khoản tài xế để sử dụng chat.',
      );
      return;
    }

    String? targetId = targetUserId;

    // Nếu chưa có targetId, tra cứu theo SĐT người nhận
    if (targetId == null || targetId.isEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
      if (cleanPhone.isNotEmpty) {
        try {
          final query = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: cleanPhone)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            targetId = query.docs.first.id;
          }
        } catch (_) {}
      }
    }

    if (targetId == null || targetId.isEmpty) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Chưa Có Tài Khoản'),
            content: Text(
              '$name hiện chưa đăng ký tài khoản JetPost trên ứng dụng.\nBạn có thể liên hệ trực tiếp bằng cuộc gọi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _callPhone(context);
                },
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Gọi Điện'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Đã có UID -> Khởi tạo chatId theo cặp UID
    final uids = [driverUid, targetId]..sort();
    final chatId = '${uids[0]}_${uids[1]}';

    if (context.mounted) {
      Navigator.pushNamed(
        context,
        AppRoutes.directChat,
        arguments: {
          'chatId': chatId,
          'targetUserId': targetId,
          'targetName': name,
          'targetPhone': phone,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Icon vai trò ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: roleColor.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(roleIcon, color: roleColor, size: 18),
        ),
        const SizedBox(width: 10),

        // ── Tên + Vai trò + SĐT ────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: roleColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name.isNotEmpty ? name : 'Không rõ tên',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                phone.isNotEmpty ? phone : 'Chưa có SĐT',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // ── Các nút hành động: Copy SĐT + Chat P2P + Gọi Điện ──────────
        if (phone.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'Sao chép SĐT',
            visualDensity: VisualDensity.compact,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
            onPressed: () => _copyPhone(context),
          ),
        ],
        if (targetUserId != null && targetUserId!.isNotEmpty)
          OrderChatButton(
            targetUserId: targetUserId!,
            targetName: name,
            targetPhone: phone,
          )
        else if (phone.isNotEmpty)
          IconButton.filledTonal(
            onPressed: () => _openChat(context),
            tooltip: 'Nhắn tin P2P',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
          ),
        if (phone.isNotEmpty) ...[
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: () => _callPhone(context),
            icon: const Icon(Icons.phone_rounded, size: 14),
            label: const Text('Gọi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ],
    );
  }
}
