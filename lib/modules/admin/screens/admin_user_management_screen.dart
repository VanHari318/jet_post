import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../controllers/admin_controller.dart';
import '../widgets/admin_widgets.dart';

/// Task 4.4 - Quản lý Tài khoản Người dùng & Thực thi Chế tài (Ban/Unban)
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends State<AdminUserManagementScreen> with SingleTickerProviderStateMixin {
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
          case 0: _roleFilter = ''; break;
          case 1: _roleFilter = 'customer'; break;
          case 2: _roleFilter = 'driver'; break;
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
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _onBanToggle(UserModel user) async {
    final isBanned = user.isBanned;
    final action = isBanned ? 'mở khóa' : 'khóa';

    final reason = isBanned ? '' : await _showBanDialog(user);
    if (!isBanned && reason == null) return; // User cancelled

    try {
      if (isBanned) {
        await _controller.unbanUser(
          userId: user.id,
          adminId: 'admin_demo_001',
        );
      } else {
        await _controller.banUser(
          userId: user.id,
          adminId: 'admin_demo_001',
          reason: reason!,
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<String?> _showBanDialog(UserModel user) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Khóa tài khoản: ${user.fullName}'),
        content: Column(
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
                  Icon(Icons.warning_amber, color: AppColors.error, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tài khoản này sẽ bị ép đăng xuất ngay lập tức và không thể đăng nhập lại.',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Lý do khóa tài khoản:'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'VD: Hủy cuốc liên tục, quấy rối hành khách...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                Navigator.pop(ctx, ctrl.text.trim());
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
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondaryLight),
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
        builder: (_) => AdminUserDetailScreen(user: user),
      ),
    );
  }
}

/// Màn hình chi tiết người dùng + lịch sử cuốc
class AdminUserDetailScreen extends StatelessWidget {
  final UserModel user;

  const AdminUserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final _controller = AdminController();

    return Scaffold(
      appBar: AppBar(
        title: Text(user.fullName),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
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
                            user.phone,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (user.isBanned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.errorBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '🔒 Tài khoản bị khóa',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Ride history
            const Text(
              'Lịch sử cuốc xe gần đây',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder(
              future: _controller.getUserRideHistory(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rides = snapshot.data ?? [];
                if (rides.isEmpty) {
                  return const Text(
                    'Chưa có lịch sử cuốc xe',
                    style: TextStyle(color: AppColors.textSecondaryLight),
                  );
                }
                return ListView.builder(
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
                        _formatDate(ride.createdAt),
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
      case 'COMPLETED': return AppColors.success;
      case 'CANCELLED': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
