import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/delivery_model.dart';
import '../../../models/ride_model.dart';

/// Bottom Sheet hiển thị đơn mới cần tài xế chấp nhận hoặc từ chối
/// Hỗ trợ cả đơn Xe Ôm (RideModel) và đơn Giao Hàng (DeliveryModel)
class IncomingOrderSheet extends StatefulWidget {
  /// Đơn xe ôm (null nếu là đơn giao hàng)
  final RideModel? ride;

  /// Đơn giao hàng (null nếu là cuốc xe ôm)
  final DeliveryModel? delivery;

  /// Callback khi tài xế bấm "Nhận đơn" — trả về true nếu thành công
  final Future<bool> Function() onAccept;

  /// Callback khi tài xế bấm "Từ chối" hoặc hết giờ đếm ngược
  final VoidCallback onDecline;

  /// Thời gian đếm ngược trước khi tự động bỏ qua (giây)
  final int countdownSeconds;

  const IncomingOrderSheet.ride({
    super.key,
    required this.ride,
    required this.onAccept,
    required this.onDecline,
    this.countdownSeconds = 30,
  })  : delivery = null;

  const IncomingOrderSheet.delivery({
    super.key,
    required this.delivery,
    required this.onAccept,
    required this.onDecline,
    this.countdownSeconds = 30,
  })  : ride = null;

  @override
  State<IncomingOrderSheet> createState() => _IncomingOrderSheetState();

  /// Mở bottom sheet từ bất kỳ màn hình nào
  static Future<void> showRide({
    required BuildContext context,
    required RideModel ride,
    required Future<bool> Function() onAccept,
    required VoidCallback onDecline,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomingOrderSheet.ride(
        ride: ride,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }

  static Future<void> showDelivery({
    required BuildContext context,
    required DeliveryModel delivery,
    required Future<bool> Function() onAccept,
    required VoidCallback onDecline,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomingOrderSheet.delivery(
        delivery: delivery,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }
}

class _IncomingOrderSheetState extends State<IncomingOrderSheet>
    with SingleTickerProviderStateMixin {
  late int _remaining;
  bool _isAccepting = false;

  // Animation đếm ngược vòng tròn
  late AnimationController _countdownController;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;

    _countdownController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.countdownSeconds),
    )..forward();

    _countdownController.addListener(() {
      final newRemaining =
          (widget.countdownSeconds * (1 - _countdownController.value)).ceil();
      if (newRemaining != _remaining && mounted) {
        setState(() => _remaining = newRemaining);
        if (newRemaining <= 0) _handleDecline();
      }
    });
  }

  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    _countdownController.stop();

    final success = await widget.onAccept();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isAccepting = false);
      _countdownController.forward();
    }
  }

  void _handleDecline() {
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onDecline();
  }

  bool get _isRide => widget.ride != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle bar ─────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Header: loại đơn + đếm ngược ──────────────────────────
              Row(
                children: [
                  // Badge loại đơn
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isRide
                          ? AppColors.primaryLight
                          : AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRide
                              ? Icons.motorcycle_rounded
                              : Icons.inventory_2_rounded,
                          color: _isRide
                              ? AppColors.primary
                              : AppColors.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isRide ? 'ĐẶT XE ÔM' : 'GIAO HÀNG',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: _isRide
                                ? AppColors.primary
                                : AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Đồng hồ đếm ngược tròn
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _countdownController,
                          builder: (context, _) => CircularProgressIndicator(
                            value: 1 - _countdownController.value,
                            strokeWidth: 4,
                            backgroundColor: AppColors.borderLight,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _remaining <= 10
                                  ? AppColors.error
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        Text(
                          '$_remaining',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _remaining <= 10
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Thông tin cuốc / đơn ────────────────────────────────────
              if (_isRide) _buildRideInfo() else _buildDeliveryInfo(),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // ── Nút Từ chối / Nhận đơn ─────────────────────────────────
              Row(
                children: [
                  // Từ chối
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAccepting ? null : _handleDecline,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Từ chối'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Nhận đơn
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isAccepting ? null : _handleAccept,
                      icon: _isAccepting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isAccepting ? 'Đang nhận...' : 'Nhận Đơn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thông tin cuốc xe ôm
  Widget _buildRideInfo() {
    final ride = widget.ride!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(
          icon: Icons.location_on_rounded,
          color: AppColors.primary,
          label: 'Điểm đón',
          value: ride.pickupAddress,
        ),
        const SizedBox(height: 10),
        _InfoLine(
          icon: Icons.flag_rounded,
          color: AppColors.secondary,
          label: 'Điểm đến',
          value: ride.dropoffAddress,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _PillInfo(
              icon: Icons.straighten_rounded,
              label: '${ride.distanceKm.toStringAsFixed(1)} km',
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            _PillInfo(
              icon: Icons.payments_rounded,
              label: '${_fmt(ride.price)}đ',
              color: AppColors.success,
            ),
            const SizedBox(width: 8),
            _PillInfo(
              icon: Icons.timer_rounded,
              label: '~${(ride.distanceKm * 2.5).toInt()} phút',
              color: AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }

  /// Thông tin đơn giao hàng
  Widget _buildDeliveryInfo() {
    final delivery = widget.delivery!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(
          icon: Icons.location_on_rounded,
          color: AppColors.primary,
          label: 'Lấy hàng',
          value: delivery.pickupAddress,
        ),
        const SizedBox(height: 10),
        _InfoLine(
          icon: Icons.flag_rounded,
          color: AppColors.secondary,
          label: 'Giao đến',
          value: delivery.dropoffAddress,
        ),
        const SizedBox(height: 10),
        _InfoLine(
          icon: Icons.inventory_2_outlined,
          color: AppColors.accent,
          label: 'Loại hàng',
          value: delivery.packageType,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _PillInfo(
              icon: Icons.straighten_rounded,
              label: '${delivery.distanceKm.toStringAsFixed(1)} km',
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            _PillInfo(
              icon: Icons.payments_rounded,
              label: '${_fmt(delivery.price)}đ',
              color: AppColors.success,
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(double price) {
    final s = price.toInt().toString();
    final buf = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write('.');
      buf.write(s[i]);
      c++;
    }
    return buf.toString().split('').reversed.join();
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PillInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PillInfo(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
