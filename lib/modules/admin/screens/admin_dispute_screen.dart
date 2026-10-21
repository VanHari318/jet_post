import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/delivery_model.dart';
import '../controllers/admin_controller.dart';

/// Task 4.5 - Quản lý Tranh chấp Đơn hàng & Đối soát PoD
class AdminDisputeScreen extends StatefulWidget {
  const AdminDisputeScreen({super.key});

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
          content: Text('Không tìm thấy đơn hàng với mã này'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDisputeDetailScreen(delivery: delivery),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xử lý Tranh chấp'),
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
                      hintText: 'Nhập mã đơn hàng để tra cứu...',
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
                  label: 'Hoàn thành',
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
                      'Không có đơn hàng nào',
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
                          builder: (_) =>
                              AdminDisputeDetailScreen(delivery: d),
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
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3)),
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
                    'Đơn: ${delivery.id.length > 12 ? delivery.id.substring(0, 12) : delivery.id}...',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
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

/// Màn hình chi tiết hồ sơ đối soát
class AdminDisputeDetailScreen extends StatelessWidget {
  final DeliveryModel delivery;

  const AdminDisputeDetailScreen({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ Đối soát'),
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
              title: '📦 Thông tin đơn hàng',
              color: AppColors.primary,
              children: [
                _Row(label: 'Mã đơn', value: delivery.id),
                _Row(label: 'Người gửi', value: '${delivery.senderName} (${delivery.senderPhone})'),
                _Row(label: 'Người nhận', value: '${delivery.receiverName} (${delivery.receiverPhone})'),
                _Row(label: 'Loại hàng', value: delivery.packageType),
                _Row(
                  label: 'Ghi chú',
                  value: (delivery.packageNote == null || delivery.packageNote!.isEmpty)
                      ? 'Không có'
                      : delivery.packageNote!,
                ),
                _Row(label: 'Cước phí', value: '${delivery.price.toStringAsFixed(0)}đ'),
              ],
            ),
            const SizedBox(height: 14),
            // Tài xế
            _DisputeSectionCard(
              title: '🏍 Thông tin tài xế',
              color: AppColors.secondary,
              children: [
                _Row(label: 'Tên tài xế', value: delivery.driverName ?? 'Chưa có'),
                _Row(label: 'SĐT tài xế', value: delivery.driverPhone ?? 'Chưa có'),
                _Row(label: 'Biển số', value: delivery.driverPlate ?? 'Chưa có'),
              ],
            ),
            const SizedBox(height: 14),
            // Trạng thái & Timestamps
            _DisputeSectionCard(
              title: '⏱ Trạng thái & Thời gian',
              color: AppColors.accent,
              children: [
                _Row(label: 'Trạng thái', value: delivery.status.toFirestore()),
                _Row(label: 'Tạo đơn', value: _formatDT(delivery.createdAt)),
                if (delivery.acceptedAt != null)
                  _Row(label: 'Tài xế nhận', value: _formatDT(delivery.acceptedAt!)),
                if (delivery.deliveredAt != null)
                  _Row(label: 'Giao thành công', value: _formatDT(delivery.deliveredAt!)),
              ],
            ),
            const SizedBox(height: 14),
            // OTP & PoD
            _DisputeSectionCard(
              title: '🔐 Bằng chứng giao hàng (PoD)',
              color: AppColors.error,
              children: [
                _Row(
                  label: 'Mã OTP bàn giao',
                  value: (delivery.handoverOtp == null || delivery.handoverOtp!.isEmpty)
                      ? 'Chưa sinh mã'
                      : delivery.handoverOtp!,
                  valueColor: AppColors.error,
                ),
                if (delivery.podPhotoUrl != null && delivery.podPhotoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Ảnh chụp giao hàng (PoD Photo):',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      delivery.podPhotoUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: AppColors.backgroundLight,
                        child: const Center(
                          child: Text('Không thể tải ảnh PoD'),
                        ),
                      ),
                    ),
                  ),
                ] else
                  const _Row(label: 'Ảnh PoD', value: 'Chưa có ảnh bằng chứng'),
              ],
            ),
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
