import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/delivery_model.dart';
import '../controllers/admin_controller.dart';

/// Task 4.5 - Quản lý Tranh chấp Đơn hàng & Đối soát PoD
class AdminDisputeScreen extends StatefulWidget {
  final String adminId;

  const AdminDisputeScreen({
    super.key,
    this.adminId = 'admin_demo_001',
  });

  @override
  State<AdminDisputeScreen> createState() => _AdminDisputeScreenState();
}

class _AdminDisputeScreenState extends State<AdminDisputeScreen> {
  final _controller = AdminController();
  final _searchCtrl = TextEditingController();
  String? _filterStatus;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchById() async {
    final id = _searchCtrl.text.trim();
    if (id.isEmpty) return;

    final delivery = await _controller.getDeliveryById(id);
    if (!mounted) return;
    if (delivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy đơn hàng với mã hoặc SĐT này'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDisputeDetailScreen(
          delivery: delivery,
          adminId: widget.adminId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xử lý Tranh chấp & PoD'),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Tra cứu theo mã đơn
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nhập mã đơn hàng hoặc SĐT để tra cứu...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => _searchById(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchById,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tra cứu'),
                ),
              ],
            ),
          ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  isSelected: _filterStatus == null,
                  onTap: () => setState(() => _filterStatus = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Hoàn thành (Có PoD)',
                  isSelected: _filterStatus == 'COMPLETED',
                  color: AppColors.success,
                  onTap: () => setState(() => _filterStatus = 'COMPLETED'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Đã hủy',
                  isSelected: _filterStatus == 'CANCELLED',
                  color: AppColors.error,
                  onTap: () => setState(() => _filterStatus = 'CANCELLED'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Giao thất bại',
                  isSelected: _filterStatus == 'FAILED_DELIVERY',
                  color: AppColors.warning,
                  onTap: () =>
                      setState(() => _filterStatus = 'FAILED_DELIVERY'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // List đơn hàng
          Expanded(
            child: StreamBuilder<List<DeliveryModel>>(
              stream: _controller.watchDeliveriesForDispute(
                  status: _filterStatus),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final deliveries = snapshot.data ?? [];
                if (deliveries.isEmpty) {
                  return const Center(
                    child: Text(
                      'Không có đơn hàng nào trong danh mục này',
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: deliveries.length,
                  itemBuilder: (context, index) {
                    final d = deliveries[index];
                    return _DeliveryDisputeCard(
                      delivery: d,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminDisputeDetailScreen(
                            delivery: d,
                            adminId: widget.adminId,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _DeliveryDisputeCard extends StatelessWidget {
  final DeliveryModel delivery;
  final VoidCallback onTap;

  const _DeliveryDisputeCard(
      {required this.delivery, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = delivery.status.toFirestore() == 'COMPLETED'
        ? AppColors.success
        : delivery.status.toFirestore() == 'CANCELLED'
            ? AppColors.error
            : AppColors.warning;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Mã đơn: ${delivery.id}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      delivery.status.toFirestore(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${delivery.senderName} → ${delivery.receiverName}',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                '${delivery.pickupAddress} → ${delivery.dropoffAddress}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 12, color: AppColors.textMutedLight),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(delivery.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMutedLight),
                  ),
                  const Spacer(),
                  Text(
                    '${delivery.price.toStringAsFixed(0)}đ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Màn hình chi tiết Hồ sơ Đối soát Kỹ thuật số & Ra quyết định phân xử (Task 4.5)
class AdminDisputeDetailScreen extends StatefulWidget {
  final DeliveryModel delivery;
  final String adminId;

  const AdminDisputeDetailScreen({
    super.key,
    required this.delivery,
    this.adminId = 'admin_demo_001',
  });

  @override
  State<AdminDisputeDetailScreen> createState() =>
      _AdminDisputeDetailScreenState();
}

class _AdminDisputeDetailScreenState extends State<AdminDisputeDetailScreen> {
  final _controller = AdminController();
  final _noteCtrl = TextEditingController();
  String _selectedDecision = 'VALID_POD';
  bool _isSavingDecision = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitResolution() async {
    setState(() => _isSavingDecision = true);
    try {
      await _controller.resolveDispute(
        deliveryId: widget.delivery.id,
        adminId: widget.adminId,
        decision: _selectedDecision,
        note: _noteCtrl.text.trim().isEmpty
            ? 'Đã đối soát ảnh PoD và mã OTP hợp lệ.'
            : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isSavingDecision = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '✅ Đã lưu phán quyết phân xử tranh chấp vào hồ sơ đối soát!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingDecision = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi lưu phán quyết: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.delivery;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ Đối soát Kỹ thuật số'),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin đơn hàng
            _DisputeSectionCard(
              title: '📦 Thông tin Người gửi & Người nhận',
              color: AppColors.primary,
              children: [
                _Row(label: 'Mã vận đơn', value: delivery.id),
                _Row(
                  label: 'Người gửi',
                  value: '${delivery.senderName} (${delivery.senderPhone})',
                ),
                _Row(
                  label: 'Người nhận',
                  value: '${delivery.receiverName} (${delivery.receiverPhone})',
                ),
                _Row(label: 'Loại hàng', value: delivery.packageType),
                _Row(
                  label: 'Ghi chú',
                  value: (delivery.packageNote == null ||
                          delivery.packageNote!.isEmpty)
                      ? 'Không có'
                      : delivery.packageNote!,
                ),
                _Row(
                  label: 'Cước phí',
                  value:
                      '${delivery.price.toStringAsFixed(0)}đ (${delivery.distanceKm.toStringAsFixed(1)} km)',
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Tài xế & Tọa độ GPS đối soát
            _DisputeSectionCard(
              title: '🏍 Tài xế & Tọa độ GPS Giao nhận',
              color: AppColors.secondary,
              children: [
                _Row(
                    label: 'Tên tài xế',
                    value: delivery.driverName ?? 'Chưa có'),
                _Row(
                    label: 'SĐT tài xế',
                    value: delivery.driverPhone ?? 'Chưa có'),
                _Row(
                    label: 'Biển số xe',
                    value: delivery.driverPlate ?? 'Chưa có'),
                _Row(
                  label: 'GPS Điểm lấy',
                  value:
                      '${delivery.pickupLat.toStringAsFixed(4)}, ${delivery.pickupLng.toStringAsFixed(4)}',
                ),
                _Row(
                  label: 'GPS Điểm giao',
                  value:
                      '${delivery.dropoffLat.toStringAsFixed(4)}, ${delivery.dropoffLng.toStringAsFixed(4)}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Trạng thái & Timestamps
            _DisputeSectionCard(
              title: '⏱ Nhật ký Thời gian & Xác thực OTP',
              color: AppColors.accent,
              children: [
                _Row(label: 'Trạng thái', value: delivery.status.toFirestore()),
                _Row(label: 'Tạo đơn lúc', value: _formatDT(delivery.createdAt)),
                if (delivery.acceptedAt != null)
                  _Row(
                      label: 'Tài xế nhận',
                      value: _formatDT(delivery.acceptedAt!)),
                if (delivery.deliveredAt != null)
                  _Row(
                      label: 'Nhập OTP & Giao',
                      value: _formatDT(delivery.deliveredAt!)),
              ],
            ),
            const SizedBox(height: 14),
            // OTP & PoD
            _DisputeSectionCard(
              title: '🔐 Bằng chứng Giao hàng (PoD & Handover OTP)',
              color: AppColors.error,
              children: [
                _Row(
                  label: 'Mã OTP 4 số',
                  value: (delivery.handoverOtp == null ||
                          delivery.handoverOtp!.isEmpty)
                      ? 'Chưa sinh mã'
                      : '${delivery.handoverOtp!} (Đã đối khớp)',
                  valueColor: AppColors.error,
                ),
                if (delivery.podPhotoUrl != null &&
                    delivery.podPhotoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Ảnh chụp bằng chứng giao hàng (PoD Photo):',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      delivery.podPhotoUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 140,
                        color: AppColors.backgroundLight,
                        child: const Center(
                          child: Text('Không thể tải ảnh PoD'),
                        ),
                      ),
                    ),
                  ),
                ] else
                  const _Row(
                      label: 'Ảnh PoD', value: 'Chưa có ảnh bằng chứng'),
              ],
            ),
            const SizedBox(height: 14),
            // Quyết định phân xử của Admin (Task 4.5 bước 3)
            _DisputeSectionCard(
              title: '⚖️ Quyết định Phân xử của Quản trị viên',
              color: AppColors.success,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedDecision,
                  decoration: InputDecoration(
                    labelText: 'Phương án xử lý',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'VALID_POD',
                      child: Text('Giao hàng hợp lệ (Đủ OTP & PoD)'),
                    ),
                    DropdownMenuItem(
                      value: 'REFUND_CUSTOMER',
                      child: Text('Hoàn cước / Đền bù cho Khách hàng'),
                    ),
                    DropdownMenuItem(
                      value: 'WARN_DRIVER',
                      child: Text('Cảnh cáo / Khóa tài xế vi phạm'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedDecision = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText:
                        'Nhập kết luận đối soát của Admin (lưu vào Audit Log)...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingDecision ? null : _submitResolution,
                    icon: const Icon(Icons.gavel),
                    label: Text(
                      _isSavingDecision
                          ? 'Đang lưu phán quyết...'
                          : 'Xác nhận Kết quả Phân xử',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
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

  String _formatDT(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DisputeSectionCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;

  const _DisputeSectionCard({
    required this.title,
    required this.color,
    required this.children,
  });

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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Divider(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondaryLight),
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
