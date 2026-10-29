import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../controllers/admin_controller.dart';
import '../services/admin_service.dart';
import '../widgets/admin_widgets.dart';
import 'admin_analytics_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_dispute_screen.dart';
import 'admin_kyc_review_screen.dart';
import 'admin_pricing_screen.dart';
import 'admin_radar_screen.dart';
import 'admin_user_management_screen.dart';

/// Task 4.1 + 4.7 - Dashboard Admin: Màn hình tổng quan điều hành
/// Tích hợp Menu Drawer, KPI Overview và điều hướng các màn hình con
class AdminDashboardScreen extends StatefulWidget {
  final UserModel adminUser;

  const AdminDashboardScreen({super.key, required this.adminUser});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentMenuIndex = 0;
  final _controller = AdminController();
  AdminAnalyticsData? _analytics;
  bool _analyticsLoading = true;
  bool _isSeeding = false;

  // Khoảng thời gian mặc định: 7 ngày gần nhất
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    _toDate = DateTime.now();
    _fromDate = _toDate.subtract(const Duration(days: 7));
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _analyticsLoading = true);
    try {
      final data =
          await _controller.getAnalytics(from: _fromDate, to: _toDate);
      if (!mounted) return;
      setState(() {
        _analytics = data;
        _analyticsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyticsLoading = false);
    }
  }

  Future<void> _seedDemoData() async {
    setState(() => _isSeeding = true);
    try {
      await _controller.seedDemoAdminData(widget.adminUser.id);
      await _loadAnalytics();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '✅ Đã nạp dữ liệu mẫu (Tài xế Radar, Hồ sơ eKYC, Đơn hàng PoD)!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tạo dữ liệu mẫu: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  void _navigateTo(int index) {
    setState(() => _currentMenuIndex = index);
    switch (index) {
      case 1:
        Navigator.push(
                context, _route(AdminRadarScreen(adminUser: widget.adminUser)))
            .then((_) => _loadAnalytics());
      case 2:
        Navigator.push(
          context,
          _route(AdminKycReviewScreen(adminId: widget.adminUser.id)),
        ).then((_) => _loadAnalytics());
      case 3:
        Navigator.push(
          context,
          _route(AdminUserManagementScreen(adminId: widget.adminUser.id)),
        ).then((_) => _loadAnalytics());
      case 4:
        Navigator.push(
          context,
          _route(AdminDisputeScreen(adminId: widget.adminUser.id)),
        );
      case 5:
        Navigator.push(
          context,
          _route(AdminPricingScreen(adminId: widget.adminUser.id)),
        );
      case 6:
        Navigator.push(context, _route(const AdminAnalyticsScreen()));
      case 7:
        Navigator.push(
          context,
          _route(AdminBroadcastScreen(adminId: widget.adminUser.id)),
        );
      default:
        break;
    }
  }

  MaterialPageRoute _route(Widget screen) =>
      MaterialPageRoute(builder: (_) => screen);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AdminDrawerMenu(
        currentIndex: _currentMenuIndex,
        onItemSelected: _navigateTo,
      ),
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Xin chào, ${widget.adminUser.fullName} 👋',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const Text(
                          'Bảng điều hành JetPost',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatDateRange(),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: _isSeeding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_fix_high, color: Colors.white),
                onPressed: _isSeeding ? null : _seedDemoData,
                tooltip: 'Nạp dữ liệu mẫu Demo',
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadAnalytics,
                tooltip: 'Làm mới dữ liệu',
              ),
            ],
          ),

          // Body content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pending KYC Badge
                  _PendingKycBanner(onReview: () => _navigateTo(2)),

                  // KPI Cards Grid
                  _SectionHeader(
                    title: 'Tổng quan 7 ngày qua',
                    action: TextButton.icon(
                      onPressed: _navigateToAnalytics,
                      icon: const Icon(Icons.bar_chart, size: 16),
                      label: const Text('Chi tiết'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      AdminStatCard(
                        title: 'Tổng doanh thu',
                        value: _analytics != null
                            ? _formatVnd(_analytics!.totalRevenue)
                            : '—',
                        subtitle: 'Phí hoa hồng hệ thống',
                        icon: Icons.attach_money,
                        color: AppColors.success,
                        isLoading: _analyticsLoading,
                      ),
                      AdminStatCard(
                        title: 'Tổng đơn hàng',
                        value: _analytics != null
                            ? '${_analytics!.totalOrders}'
                            : '—',
                        subtitle:
                            '${_analytics?.completedOrders ?? 0} hoàn thành',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.primary,
                        isLoading: _analyticsLoading,
                      ),
                      AdminStatCard(
                        title: 'Người dùng mới',
                        value: _analytics != null
                            ? '${_analytics!.newUsers}'
                            : '—',
                        subtitle: 'Đăng ký trong kỳ',
                        icon: Icons.person_add_outlined,
                        color: AppColors.accent,
                        isLoading: _analyticsLoading,
                      ),
                      AdminStatCard(
                        title: 'Tài xế hoạt động',
                        value: _analytics != null
                            ? '${_analytics!.activeDrivers}'
                            : '—',
                        subtitle: 'Đã được kích hoạt',
                        icon: Icons.motorcycle,
                        color: AppColors.secondary,
                        isLoading: _analyticsLoading,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  const _SectionHeader(title: 'Trung tâm Điều hành (8 Nghiệp vụ)'),
                  const SizedBox(height: 12),
                  _QuickActionsGrid(onNavigate: _navigateTo),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAnalytics() => _navigateTo(6);

  String _formatDateRange() {
    return 'Kỳ báo cáo: ${_fromDate.day}/${_fromDate.month} - ${_toDate.day}/${_toDate.month}/${_toDate.year}';
  }

  String _formatVnd(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}T đ';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M đ';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k đ';
    }
    return '${value.toStringAsFixed(0)} đ';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        ?action,
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const _QuickActionsGrid({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final actions = [
      const _QuickAction(
        icon: Icons.radar,
        label: 'Radar\nĐiều hành',
        color: AppColors.primary,
        index: 1,
      ),
      const _QuickAction(
        icon: Icons.assignment_ind_outlined,
        label: 'Duyệt hồ\nsơ eKYC',
        color: AppColors.warning,
        index: 2,
      ),
      const _QuickAction(
        icon: Icons.manage_accounts_outlined,
        label: 'Quản lý\nNgười dùng',
        color: AppColors.accent,
        index: 3,
      ),
      const _QuickAction(
        icon: Icons.gavel_outlined,
        label: 'Tranh chấp\n& PoD',
        color: AppColors.error,
        index: 4,
      ),
      const _QuickAction(
        icon: Icons.price_change_outlined,
        label: 'Cấu hình\nBiểu cước',
        color: AppColors.secondary,
        index: 5,
      ),
      const _QuickAction(
        icon: Icons.bar_chart_rounded,
        label: 'Báo cáo\nThống kê',
        color: AppColors.success,
        index: 6,
      ),
      const _QuickAction(
        icon: Icons.campaign_outlined,
        label: 'Phát\nThông báo',
        color: AppColors.info,
        index: 7,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.08,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) {
        final action = actions[i];
        return _QuickActionCard(
          action: action,
          onTap: () => onNavigate(action.index),
        );
      },
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final int index;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.index,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  final VoidCallback onTap;

  const _QuickActionCard({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: action.color.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: action.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingKycBanner extends StatelessWidget {
  final VoidCallback onReview;

  const _PendingKycBanner({required this.onReview});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AdminController().watchPendingDriverApprovals(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withValues(alpha: 0.15),
                  AppColors.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_late,
                      color: AppColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count hồ sơ đang chờ duyệt!',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        'Tài xế mới đã nộp hồ sơ eKYC',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onReview,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    backgroundColor: AppColors.warningBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Xét duyệt',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
