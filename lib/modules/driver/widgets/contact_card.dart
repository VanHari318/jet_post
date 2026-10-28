import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

/// Card hiển thị thông tin liên lạc
/// - Xe Ôm: 1 liên lạc (khách hàng)
/// - Giao Hàng: 2 liên lạc (người gửi + người nhận)
class ContactCard extends StatelessWidget {
  /// true = đơn giao hàng, false = xe ôm
  final bool isDelivery;

  // ── Thông tin xe ôm ──────────────────────────────────────────────────────
  final String? customerName;
  final String? customerPhone;

  // ── Thông tin giao hàng ───────────────────────────────────────────────────
  final String? senderName;
  final String? senderPhone;
  final String? receiverName;
  final String? receiverPhone;

  const ContactCard.ride({
    super.key,
    required this.customerName,
    required this.customerPhone,
  })  : isDelivery = false,
        senderName = null,
        senderPhone = null,
        receiverName = null,
        receiverPhone = null;

  const ContactCard.delivery({
    super.key,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
  })  : isDelivery = true,
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
                  child: const Icon(Icons.contact_phone_rounded,
                      color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Thông Tin Liên Lạc',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
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
                roleColor: AppColors.primary,
                roleIcon: Icons.person_rounded,
              ),
            ] else ...[
              // ── Giao Hàng: người gửi + người nhận ──────────────────────
              _ContactRow(
                role: 'Người Gửi',
                name: senderName ?? '',
                phone: senderPhone ?? '',
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

/// Row liên lạc cho một người — tên + SĐT + nút gọi + nút sao chép
class _ContactRow extends StatelessWidget {
  final String role;
  final String name;
  final String phone;
  final Color roleColor;
  final IconData roleIcon;

  const _ContactRow({
    required this.role,
    required this.name,
    required this.phone,
    required this.roleColor,
    required this.roleIcon,
  });

  /// Gọi điện bằng url_launcher
  Future<void> _callPhone(BuildContext context) async {
    // Chuẩn hóa SĐT: loại bỏ dấu cách, dấu gạch
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
              ),
              const SizedBox(height: 1),
              Text(
                phone.isNotEmpty ? phone : 'Chưa có SĐT',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                ),
              ),
            ],
          ),
        ),

        // ── Nút sao chép SĐT ───────────────────────────────────────────
        if (phone.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Sao chép SĐT',
            color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
            onPressed: () => _copyPhone(context),
          ),

          // ── Nút gọi điện ────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () => _callPhone(context),
            icon: const Icon(Icons.phone_rounded, size: 16),
            label: const Text('Gọi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
