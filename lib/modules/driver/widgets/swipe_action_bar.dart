import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Widget SwipeActionBar — Thanh lướt xác nhận hành động tài xế
///
/// Tài xế phải kéo thumb sang phải ≥ 85% chiều dài thanh.
/// Sau đó hiện AlertDialog xác nhận. Chỉ khi bấm "Đồng ý" mới
/// gọi [onConfirmed] và cập nhật trạng thái lên Firestore.
/// Nếu huỷ hoặc chưa kéo đủ → thumb tự trở về vị trí ban đầu.
class SwipeActionBar extends StatefulWidget {
  /// Nhãn hiển thị trong thanh trượt (VD: "Đã đến điểm đón →→→")
  final String label;

  /// Tiêu đề của AlertDialog xác nhận
  final String confirmTitle;

  /// Nội dung mô tả trong AlertDialog
  final String confirmMessage;

  /// Callback gọi khi tài xế bấm "Đồng ý" trong dialog
  final VoidCallback onConfirmed;

  /// Màu nền của thanh (mặc định dùng AppColors.primary)
  final Color? trackColor;

  /// Có đang loading (khóa tương tác) không?
  final bool isLoading;

  const SwipeActionBar({
    super.key,
    required this.label,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.onConfirmed,
    this.trackColor,
    this.isLoading = false,
  });

  @override
  State<SwipeActionBar> createState() => _SwipeActionBarState();
}

class _SwipeActionBarState extends State<SwipeActionBar>
    with SingleTickerProviderStateMixin {
  // Tỉ lệ vị trí thumb: 0.0 (trái) → 1.0 (phải)
  double _dragRatio = 0.0;

  // Ngưỡng lướt tối thiểu để kích hoạt dialog (85%)
  static const double _threshold = 0.85;

  // Chiều cao cố định của thanh
  static const double _barHeight = 60.0;
  static const double _thumbSize = 48.0;

  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  bool _isConfirming = false; // Đang hiện dialog

  @override
  void initState() {
    super.initState();
    // Animation snap về 0 khi thả thumb
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _snapAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    )..addListener(() {
        setState(() => _dragRatio = _snapAnimation.value);
      });
  }

  /// Animate thumb trở về vị trí ban đầu (0)
  void _snapBack() {
    _snapAnimation = Tween<double>(begin: _dragRatio, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    )..addListener(() {
        if (mounted) setState(() => _dragRatio = _snapAnimation.value);
      });
    _snapController.forward(from: 0);
  }

  void _onDragUpdate(DragUpdateDetails details, double trackWidth) {
    if (widget.isLoading || _isConfirming) return;
    final maxTravel = trackWidth - _thumbSize - 8;
    setState(() {
      _dragRatio =
          ((_dragRatio * maxTravel + details.delta.dx) / maxTravel).clamp(
        0.0,
        1.0,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.isLoading || _isConfirming) return;
    if (_dragRatio >= _threshold) {
      _showConfirmDialog();
    } else {
      _snapBack();
    }
  }

  Future<void> _showConfirmDialog() async {
    _isConfirming = true;
    _snapBack();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.confirmTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          widget.confirmMessage,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(ctx).colorScheme.onSurface.withAlpha(180),
            height: 1.5,
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          // Nút Huỷ
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Huỷ'),
          ),
          // Nút Đồng ý
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Đồng ý',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    _isConfirming = false;

    if (confirmed == true) {
      widget.onConfirmed();
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackColor = widget.trackColor ?? AppColors.primary;
    final isDisabled = widget.isLoading || _isConfirming;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxTravel = trackWidth - _thumbSize - 8;
        final thumbOffset = _dragRatio * maxTravel + 4;

        return Opacity(
          opacity: isDisabled ? 0.6 : 1.0,
          child: Container(
            height: _barHeight,
            decoration: BoxDecoration(
              color: trackColor.withAlpha(30),
              borderRadius: BorderRadius.circular(_barHeight / 2),
              border: Border.all(color: trackColor.withAlpha(80), width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // ── Thanh tiến trình fill từ trái ──────────────────────────
                AnimatedContainer(
                  duration: Duration.zero,
                  width: thumbOffset + _thumbSize / 2,
                  decoration: BoxDecoration(
                    color: trackColor.withAlpha(50),
                    borderRadius: BorderRadius.circular(_barHeight / 2),
                  ),
                ),

                // ── Nhãn hướng dẫn ─────────────────────────────────────────
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(left: _thumbSize + 12),
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: trackColor,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // ── Mũi tên gợi ý lướt ─────────────────────────────────────
                Positioned(
                  right: 12,
                  child: Opacity(
                    opacity: 1.0 - _dragRatio,
                    child: Row(
                      children: [
                        Icon(Icons.chevron_right,
                            color: trackColor.withAlpha(120), size: 20),
                        Icon(Icons.chevron_right,
                            color: trackColor.withAlpha(80), size: 20),
                      ],
                    ),
                  ),
                ),

                // ── Thumb (nút kéo) ─────────────────────────────────────────
                Positioned(
                  left: thumbOffset,
                  child: GestureDetector(
                    onHorizontalDragUpdate: isDisabled
                        ? null
                        : (d) => _onDragUpdate(d, trackWidth),
                    onHorizontalDragEnd:
                        isDisabled ? null : _onDragEnd,
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        color: trackColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: trackColor.withAlpha(100),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: widget.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
