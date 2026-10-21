import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';
import '../controllers/admin_controller.dart';
import '../widgets/admin_widgets.dart';

/// Task 4.3 - Thẩm định & Phê duyệt Hồ sơ Đối tác Tài xế eKYC
class AdminKycReviewScreen extends StatefulWidget {
  const AdminKycReviewScreen({super.key});

  @override
  State<AdminKycReviewScreen> createState() => _AdminKycReviewScreenState();
}

class _AdminKycReviewScreenState extends State<AdminKycReviewScreen> {
  final _controller = AdminController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt Hồ sơ eKYC'),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<DriverModel>>(
        stream: _controller.watchPendingDriverApprovals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final drivers = snapshot.data ?? [];
          if (drivers.isEmpty) {
            return const _EmptyKycList();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return FutureBuilder<UserModel?>(
                future: _controller.getUserByDriverId(driver.id),
                builder: (context, userSnap) {
                  return KycReviewCard(
                    driver: driver,
                    userInfo: userSnap.data,
                    onReview: () => _openKycDetail(driver, userSnap.data),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openKycDetail(DriverModel driver, UserModel? userInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminKycDetailScreen(
          driver: driver,
          userInfo: userInfo,
        ),
      ),
    );
  }
}

/// Màn hình chi tiết xem ảnh giấy tờ và ra quyết định duyệt/từ chối
class AdminKycDetailScreen extends StatefulWidget {
  final DriverModel driver;
  final UserModel? userInfo;

  const AdminKycDetailScreen({
    super.key,
    required this.driver,
    this.userInfo,
  });

  @override
  State<AdminKycDetailScreen> createState() => _AdminKycDetailScreenState();
}

class _AdminKycDetailScreenState extends State<AdminKycDetailScreen> {
  final _controller = AdminController();
  bool _isProcessing = false;
  final _rejectReasonCtrl = TextEditingController();

  @override
  void dispose() {
    _rejectReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      await _controller.approveDriver(
        driverId: widget.driver.id,
        adminId: 'admin_demo_001', // TODO: lấy từ Auth
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('✅ Đã phê duyệt tài xế thành công!', AppColors.success);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar('Lỗi: $e', AppColors.error);
    }
  }

  Future<void> _showRejectDialog() async {
    _rejectReasonCtrl.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối hồ sơ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhập lý do từ chối (sẽ gửi về app tài xế):'),
            const SizedBox(height: 10),
            TextField(
              controller: _rejectReasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'VD: Ảnh bằng lái bị lóa, vui lòng chụp lại rõ hơn...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );

    if (confirmed == true && _rejectReasonCtrl.text.isNotEmpty) {
      setState(() => _isProcessing = true);
      try {
        await _controller.rejectDriver(
          driverId: widget.driver.id,
          adminId: 'admin_demo_001',
          reason: _rejectReasonCtrl.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        _showSnackBar('Đã từ chối và gửi lý do tới tài xế', AppColors.warning);
      } catch (e) {
        setState(() => _isProcessing = false);
        _showSnackBar('Lỗi: $e', AppColors.error);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final user = widget.userInfo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Hồ sơ'),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin cá nhân
            _SectionCard(
              title: 'Thông tin tài xế',
              child: Column(
                children: [
                  _DetailRow(label: 'Họ tên', value: user?.fullName ?? 'N/A'),
                  _DetailRow(label: 'Số điện thoại', value: user?.phone ?? 'N/A'),
                  _DetailRow(label: 'Biển số xe', value: driver.plateNumber),
                  _DetailRow(label: 'Loại xe', value: driver.vehicleType),
                  _DetailRow(
                    label: 'Trạng thái',
                    value: 'Chờ xét duyệt',
                    valueColor: AppColors.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Ảnh CCCD
            const Text(
              'Căn cước công dân (CCCD)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DocumentImageCard(
                    title: 'Mặt trước',
                    imageUrl: driver.idCardFrontUrl,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DocumentImageCard(
                    title: 'Mặt sau',
                    imageUrl: driver.idCardBackUrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Ảnh GPLX
            const Text(
              'Giấy phép lái xe (GPLX)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _DocumentImageCard(
              title: 'Giấy phép lái xe',
              imageUrl: driver.licenseUrl,
              fullWidth: true,
            ),
            const SizedBox(height: 24),
            // Action buttons
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showRejectDialog,
                      icon: const Icon(Icons.close, color: AppColors.error),
                      label: const Text('Từ chối',
                          style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Phê duyệt kích hoạt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentImageCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final bool fullWidth;

  const _DocumentImageCard({
    required this.title,
    this.imageUrl,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
              ),
            )
          : _ImagePlaceholder(label: title),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String? label;

  const _ImagePlaceholder({this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported_outlined,
            size: 36, color: AppColors.textMutedLight),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMutedLight)),
        ],
      ],
    );
  }
}

class _EmptyKycList extends StatelessWidget {
  const _EmptyKycList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 72, color: AppColors.success),
          const SizedBox(height: 16),
          const Text(
            'Không có hồ sơ chờ duyệt',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tất cả hồ sơ đã được xét duyệt',
            style: TextStyle(color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}
