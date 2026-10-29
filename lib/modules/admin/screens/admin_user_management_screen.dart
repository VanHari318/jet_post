import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../models/ride_model.dart';
import '../../../models/user_model.dart';
import '../controllers/admin_controller.dart';
import '../widgets/admin_widgets.dart';

/// Task 4.4 - Quản lý Tài khoản Người dùng & Thực thi Chế tài (Ban/Unban)
class AdminUserManagementScreen extends StatefulWidget {
  final String adminId;

  const AdminUserManagementScreen({
    super.key,
    this.adminId = 'admin_demo_001',
  });

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen>
    with SingleTickerProviderStateMixin {
  final _controller = AdminController();
  final _searchCtrl = TextEditingController();
  String _roleFilter = '';
  List<UserModel>? _searchResults;
  bool _isSearching = false;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        switch (_tabCtrl.index) {
          case 0:
            _roleFilter = '';
            break;
          case 1:
            _roleFilter = 'customer';
            break;
          case 2:
            _roleFilter = 'driver';
            break;
        }
        setState(() => _searchResults = null);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String keyword) async {
    if (keyword.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    setState(() => _isSearching = true);
    final results = await _controller.searchUsers(keyword);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _onBanToggle(UserModel user) async {
    final isBanned = user.isBanned;
    final action = isBanned ? 'mở khóa' : 'khóa';

    Map<String, String>? banResult;
    if (!isBanned) {
      banResult = await _showBanDialog(user);
      if (banResult == null) return; // User cancelled
    }

    try {
      if (isBanned) {
        await _controller.unbanUser(
          userId: user.id,
          adminId: widget.adminId,
        );
      } else {
        await _controller.banUser(
          userId: user.id,
          adminId: widget.adminId,
          reason: banResult!['reason']!,
          duration: banResult['duration'] ?? 'PERMANENT',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã $action tài khoản ${user.fullName} thành công'),
          backgroundColor: isBanned ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_searchResults != null && _searchCtrl.text.isNotEmpty) {
        _onSearch(_searchCtrl.text);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<Map<String, String>?> _showBanDialog(UserModel user) async {
    final ctrl = TextEditingController();
    String selectedDuration = 'PERMANENT';

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Khóa tài khoản: ${user.fullName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: AppColors.error, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tài khoản này sẽ bị ép đăng xuất ngay lập tức và không thể đăng nhập lại.',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thời hạn khóa:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _DurationChip(
                      label: '24 giờ',
                      value: '24H',
                      selected: selectedDuration == '24H',
                      onTap: () =>
                          setDialogState(() => selectedDuration = '24H'),
                    ),
                    _DurationChip(
                      label: '7 ngày',
                      value: '7D',
                      selected: selectedDuration == '7D',
                      onTap: () =>
                          setDialogState(() => selectedDuration = '7D'),
                    ),
                    _DurationChip(
                      label: '30 ngày',
                      value: '30D',
                      selected: selectedDuration == '30D',
                      onTap: () =>
                          setDialogState(() => selectedDuration = '30D'),
                    ),
                    _DurationChip(
                      label: 'Vĩnh viễn',
                      value: 'PERMANENT',
                      selected: selectedDuration == 'PERMANENT',
                      onTap: () =>
                          setDialogState(() => selectedDuration = 'PERMANENT'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lý do khóa tài khoản:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'VD: Hủy cuốc liên tục, bom hàng, gian lận...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, {
                    'reason': ctrl.text.trim(),
                    'duration': selectedDuration,
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xác nhận khóa'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Người dùng'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Khách hàng'),
            Tab(text: 'Tài xế'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc số điện thoại...',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textSecondaryLight),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // Content
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults != null
                    ? _buildUserList(_searchResults!)
                    : StreamBuilder<List<UserModel>>(
                        stream: _controller.watchUsers(
                          roleFilter: _roleFilter.isEmpty ? null : _roleFilter,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final users = snapshot.data ?? [];
                          return _buildUserList(users);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<UserModel> users) {
    if (users.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy người dùng nào',
          style: TextStyle(color: AppColors.textSecondaryLight),
        ),
      );
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return UserManagementCard(
          user: user,
          onViewDetail: () => _openUserDetail(user),
          onBanToggle: () => _onBanToggle(user),
        );
      },
    );
  }

  void _openUserDetail(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailScreen(
          user: user,
          onBanToggle: () => _onBanToggle(user),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.error : AppColors.errorBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.error,
          ),
        ),
      ),
    );
  }
}

/// Màn hình chi tiết người dùng + tỷ lệ hủy cuốc + lịch sử cuốc
class AdminUserDetailScreen extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onBanToggle;

  const AdminUserDetailScreen({
    super.key,
    required this.user,
    this.onBanToggle,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AdminController();
    final isDriver = user.role == UserRole.driver;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.fullName),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        actions: [
          if (onBanToggle != null)
            IconButton(
              icon: Icon(user.isBanned ? Icons.lock_open : Icons.block),
              tooltip: user.isBanned ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
              onPressed: () {
                Navigator.pop(context);
                onBanToggle!();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.accentLight,
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? const Icon(Icons.person,
                              size: 36, color: AppColors.accent)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.phone.isNotEmpty
                                ? user.phone
                                : (user.email ?? ''),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  user.role.displayName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (user.isBanned) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '🔒 Bị khóa (BANNED)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lịch sử cuốc & Tỷ lệ hủy cuốc (Task 4.4)
            FutureBuilder<List<RideModel>>(
              future: isDriver
                  ? controller.getDriverRideHistory(user.id)
                  : controller.getUserRideHistory(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rides = snapshot.data ?? [];
                final total = rides.length;
                final completed = rides
                    .where((r) => r.status.toFirestore() == 'COMPLETED')
                    .length;
                final cancelled = rides
                    .where((r) => r.status.toFirestore() == 'CANCELLED')
                    .length;
                final cancelRate =
                    total > 0 ? (cancelled / total * 100) : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thẻ chỉ số uy tín & tỷ lệ hủy cuốc
                    Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MetricColumn(
                              label: 'Tổng cuốc',
                              value: '$total',
                              color: AppColors.accent,
                            ),
                            _MetricColumn(
                              label: 'Hoàn thành',
                              value: '$completed',
                              color: AppColors.success,
                            ),
                            _MetricColumn(
                              label: 'Đã hủy',
                              value: '$cancelled',
                              color: AppColors.error,
                            ),
                            _MetricColumn(
                              label: 'Tỷ lệ hủy',
                              value: '${cancelRate.toStringAsFixed(1)}%',
                              color: cancelRate > 30
                                  ? AppColors.error
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Lịch sử cuốc xe gần đây',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (rides.isEmpty)
                      const Text(
                        'Chưa có lịch sử cuốc xe',
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rides.length,
                        itemBuilder: (context, i) {
                          final ride = rides[i];
                          return ListTile(
                            leading: Icon(
                              Icons.motorcycle,
                              color: _statusColor(ride.status.toFirestore()),
                            ),
                            title: Text(
                              '${ride.pickupAddress} → ${ride.dropoffAddress}',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_formatDate(ride.createdAt)} • ${ride.status.displayName}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              '${ride.price.toStringAsFixed(0)}đ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
