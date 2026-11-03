import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/currency_formatter.dart';
import '../services/customer_service.dart';

/// Hộp thoại thanh toán hóa đơn tiền mặt & Đánh giá sao chuyến đi (PoD Review)
class TripRatingDialog extends StatefulWidget {
  final String tripId;
  final String? driverId;
  final String driverName;
  final double price;
  final bool isDelivery;
  final String? podPhotoUrl;
  final VoidCallback onDismissed;

  const TripRatingDialog({
    super.key,
    required this.tripId,
    this.driverId,
    required this.driverName,
    required this.price,
    this.isDelivery = false,
    this.podPhotoUrl,
    required this.onDismissed,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    String? driverId,
    required String driverName,
    required double price,
    bool isDelivery = false,
    String? podPhotoUrl,
    required VoidCallback onDismissed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TripRatingDialog(
        tripId: tripId,
        driverId: driverId,
        driverName: driverName,
        price: price,
        isDelivery: isDelivery,
        podPhotoUrl: podPhotoUrl,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  State<TripRatingDialog> createState() => _TripRatingDialogState();
}

class _TripRatingDialogState extends State<TripRatingDialog> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  final List<String> _selectedTags = [];
  bool _isSubmitting = false;

  final List<String> _quickTags = [
    'Lái xe an toàn',
    'Thân thiện & Lịch sự',
    'Đúng giờ',
    'Giao hàng cẩn thận',
    'Xe sạch sẽ',
    'Nhiệt tình hỗ trợ',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      final commentBuffer = StringBuffer();
      if (_selectedTags.isNotEmpty) {
        commentBuffer.write('[${_selectedTags.join(', ')}] ');
      }
      commentBuffer.write(_commentController.text.trim());
      final finalComment = commentBuffer.toString().trim();

      if (widget.isDelivery) {
        await CustomerService.instance.rateDelivery(
          deliveryId: widget.tripId,
          driverId: widget.driverId ?? '',
          rating: _rating,
          reviewComment: finalComment.isNotEmpty ? finalComment : null,
        );
      } else {
        await CustomerService.instance.rateRide(
          rideId: widget.tripId,
          driverId: widget.driverId ?? '',
          rating: _rating,
          reviewComment: finalComment.isNotEmpty ? finalComment : null,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onDismissed();

      AppDialogs.showSuccess(
        context,
        title: 'Cảm Ơn Đánh Giá!',
        message:
            'Đánh giá của bạn đã được ghi nhận. Chúc bạn có những trải nghiệm tuyệt vời cùng JetPost!',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppDialogs.showError(context,
          title: 'Lỗi Đánh Giá', message: 'Không thể gửi đánh giá: $e');
    }
  }

  void _showEnlargedPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                CloudinaryService.instance.getOptimizedUrl(url, width: 800),
                fit: BoxFit.contain,
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon hoàn tất
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 14),

            // Tiêu đề
            Text(
              widget.isDelivery ? 'Giao Hàng Thành Công!' : 'Chuyến Đi Hoàn Tất!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tài xế: ${widget.driverName}',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),

            // Hóa đơn thanh toán tiền mặt
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Cước tiền mặt (CASH):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    CurrencyFormatter.format(widget.price),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Bằng chứng giao hàng PoD Photo (nếu có)
            if (widget.isDelivery &&
                widget.podPhotoUrl != null &&
                widget.podPhotoUrl!.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bằng chứng giao hàng (Proof of Delivery - PoD):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () =>
                    _showEnlargedPhoto(context, widget.podPhotoUrl!),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          CloudinaryService.instance.getOptimizedUrl(
                            widget.podPhotoUrl!,
                            width: 300,
                            height: 150,
                          ),
                          fit: BoxFit.cover,
                        ),
                        Container(
                          color: Colors.black.withAlpha(40),
                          child: const Center(
                            child: Icon(Icons.zoom_in,
                                color: Colors.white, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Chọn số sao đánh giá (1 - 5 sao)
            Text(
              'Bạn đánh giá dịch vụ thế nào?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  icon: Icon(
                    starValue <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 36,
                  ),
                  onPressed: () {
                    setState(() => _rating = starValue);
                  },
                );
              }),
            ),
            const SizedBox(height: 10),

            // Quick Tags nhận xét
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return ChoiceChip(
                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => _toggleTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Ô nhận xét chi tiết
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Nhận xét thêm về chuyến đi (không bắt buộc)...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Nút bấm xác nhận & bỏ qua
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.pop(context);
                            widget.onDismissed();
                          },
                    child: Text(
                      'Bỏ qua',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Gửi Đánh Giá',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

