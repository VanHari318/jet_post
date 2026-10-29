import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/system_notification_model.dart';
import '../controllers/admin_controller.dart';
import '../widgets/admin_widgets.dart';

/// Task 4.8 - Trung tâm Phát Thông báo & Cảnh báo Vận hành Toàn hệ thống
class AdminBroadcastScreen extends StatefulWidget {
  final String adminId;

  const AdminBroadcastScreen({super.key, required this.adminId});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen>
    with SingleTickerProviderStateMixin {
  final _controller = AdminController();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _targetGroup = 'ALL';
  String _priority = 'NORMAL';
  bool _isBroadcasting = false;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate({
    required String title,
    required String body,
    required String targetGroup,
    required String priority,
  }) {
    setState(() {
      _titleCtrl.text = title;
      _bodyCtrl.text = body;
      _targetGroup = targetGroup;
      _priority = priority;
    });
  }

  Future<void> _broadcast() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBroadcasting = true);

    try {
      await _controller.broadcastNotification(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        targetGroup: _targetGroup,
        priority: _priority,
        adminId: widget.adminId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📢 Đã phát thông báo thành công tới toàn mạng lưới!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset form
      _titleCtrl.clear();
      _bodyCtrl.clear();
      setState(() {
        _targetGroup = 'ALL';
        _priority = 'NORMAL';
        _isBroadcasting = false;
      });

      // Chuyển sang tab lịch sử
      _tabCtrl.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBroadcasting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi phát thông báo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phát Thông báo'),
        backgroundColor: AppColors.info,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.campaign), text: 'Soạn thông báo'),
            Tab(icon: Icon(Icons.history), text: 'Lịch sử'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Tab 1: Soạn thông báo
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alert theo context
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.broadcast_on_personal,
                            color: AppColors.info, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Thông báo sẽ xuất hiện tức thì trên app của tất cả người dùng mục tiêu.',
                            style:
                                TextStyle(fontSize: 12, color: AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mẫu thông báo nhanh theo KeHoach.md Task 4.8
                  const Text(
                    'Mẫu thông báo nhanh (1 chạm)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.thunderstorm_outlined,
                              size: 16, color: AppColors.warning),
                          label: const Text('Cảnh báo mưa ngập',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () => _applyTemplate(
                            title: 'Cảnh báo mưa to ngập lụt khu vực Đống Đa',
                            body:
                                'Đề nghị đối tác tài xế lái xe an toàn, bật đèn cảnh báo và bọc nilon bảo quản bưu kiện cẩn thận.',
                            targetGroup: 'DRIVERS',
                            priority: 'URGENT',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.local_offer_outlined,
                              size: 16, color: AppColors.primary),
                          label: const Text('Ưu đãi cước phí',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () => _applyTemplate(
                            title: 'Ưu đãi 20% cước Giao hàng Nhanh JetPost',
                            body:
                                'Đặt xe ôm và gửi hàng siêu tốc trên JetPost ngay hôm nay để nhận ưu đãi giảm giá trực tiếp!',
                            targetGroup: 'CUSTOMERS',
                            priority: 'NORMAL',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tiêu đề
                  const Text(
                    'Tiêu đề thông báo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'VD: Cảnh báo mưa to ngập lụt...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.title),
                    ),
                    maxLength: 80,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Vui lòng nhập tiêu đề'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Nội dung
                  const Text(
                    'Nội dung thông điệp',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bodyCtrl,
                    decoration: InputDecoration(
                      hintText:
                          'Nhập nội dung chi tiết thông báo muốn gửi đến người dùng...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    maxLength: 300,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Vui lòng nhập nội dung'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Đối tượng nhận
                  const Text(
                    'Đối tượng nhận thông báo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      BroadcastTargetChip(
                        label: 'Toàn mạng lưới',
                        icon: Icons.public,
                        color: AppColors.accent,
                        isSelected: _targetGroup == 'ALL',
                        onTap: () => setState(() => _targetGroup = 'ALL'),
                      ),
                      BroadcastTargetChip(
                        label: 'Chỉ Tài xế',
                        icon: Icons.motorcycle,
                        color: AppColors.primary,
                        isSelected: _targetGroup == 'DRIVERS',
                        onTap: () => setState(() => _targetGroup = 'DRIVERS'),
                      ),
                      BroadcastTargetChip(
                        label: 'Chỉ Khách hàng',
                        icon: Icons.person,
                        color: AppColors.secondary,
                        isSelected: _targetGroup == 'CUSTOMERS',
                        onTap: () => setState(() => _targetGroup = 'CUSTOMERS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Mức ưu tiên
                  const Text(
                    'Mức độ ưu tiên',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _PriorityRadio(
                        label: 'Thông thường',
                        value: 'NORMAL',
                        color: AppColors.info,
                        groupValue: _priority,
                        onChanged: (v) => setState(() => _priority = v),
                      ),
                      const SizedBox(width: 12),
                      _PriorityRadio(
                        label: 'Quan trọng',
                        value: 'HIGH',
                        color: AppColors.warning,
                        groupValue: _priority,
                        onChanged: (v) => setState(() => _priority = v),
                      ),
                      const SizedBox(width: 12),
                      _PriorityRadio(
                        label: 'Khẩn cấp',
                        value: 'URGENT',
                        color: AppColors.error,
                        groupValue: _priority,
                        onChanged: (v) => setState(() => _priority = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Preview
                  _NotificationPreview(
                    title: _titleCtrl.text,
                    body: _bodyCtrl.text,
                    targetGroup: _targetGroup,
                    priority: _priority,
                    titleCtrl: _titleCtrl,
                    bodyCtrl: _bodyCtrl,
                  ),
                  const SizedBox(height: 20),

                  // Broadcast button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isBroadcasting ? null : _broadcast,
                      icon: _isBroadcasting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isBroadcasting
                            ? 'Đang phát...'
                            : 'Phát thông báo ngay (Broadcast)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Tab 2: Lịch sử thông báo
          StreamBuilder<List<SystemNotificationModel>>(
            stream: _controller.watchBroadcastHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final notifications = snapshot.data ?? [];
              if (notifications.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 56, color: AppColors.textMutedLight),
                      SizedBox(height: 12),
                      Text(
                        'Chưa có thông báo nào được phát',
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  return NotificationHistoryCard(
                    title: n.title,
                    body: n.body,
                    targetGroup: n.targetGroup,
                    priority: n.priority.toFirestore(),
                    createdAt: n.createdAt,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PriorityRadio extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _PriorityRadio({
    required this.label,
    required this.value,
    required this.color,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.borderLight,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget preview thông báo trực quan
class _NotificationPreview extends StatefulWidget {
  final String title;
  final String body;
  final String targetGroup;
  final String priority;
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;

  const _NotificationPreview({
    required this.title,
    required this.body,
    required this.targetGroup,
    required this.priority,
    required this.titleCtrl,
    required this.bodyCtrl,
  });

  @override
  State<_NotificationPreview> createState() => _NotificationPreviewState();
}

class _NotificationPreviewState extends State<_NotificationPreview> {
  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.titleCtrl.addListener(_onTextChanged);
    widget.bodyCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.titleCtrl.removeListener(_onTextChanged);
    widget.bodyCtrl.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewTitle = widget.titleCtrl.text.isEmpty
        ? 'Tiêu đề thông báo'
        : widget.titleCtrl.text;
    final previewBody = widget.bodyCtrl.text.isEmpty
        ? 'Nội dung thông báo sẽ hiển thị ở đây...'
        : widget.bodyCtrl.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Xem trước thông báo',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      previewBody,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Vừa xong • JetPost',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
