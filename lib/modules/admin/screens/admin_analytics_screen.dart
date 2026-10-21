import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/admin_controller.dart';
import '../services/admin_service.dart';
import '../widgets/admin_widgets.dart';

/// Task 4.7 - Báo cáo Thống kê & Phân tích Kinh doanh
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _controller = AdminController();
  AdminAnalyticsData? _analytics;
  List<DailyRevenueData> _dailyRevenue = [];
  bool _isLoading = false;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  String _selectedPeriod = '7 ngày';

  final List<String> _periods = ['7 ngày', '30 ngày', 'Tháng này', 'Tuần này'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _selectPeriod(String period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriod = period;
      switch (period) {
        case '7 ngày':
          _fromDate = now.subtract(const Duration(days: 7));
          _toDate = now;
        case '30 ngày':
          _fromDate = now.subtract(const Duration(days: 30));
          _toDate = now;
        case 'Tháng này':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = now;
        case 'Tuần này':
          _fromDate = now.subtract(Duration(days: now.weekday - 1));
          _toDate = now;
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
        final analytics =
          await _controller.getAnalytics(from: _fromDate, to: _toDate);
        final daily =
          await _controller.getDailyRevenue(from: _fromDate, to: _toDate);
      setState(() {
        _analytics = analytics;
        _dailyRevenue = daily;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê & Báo cáo'),
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periods.map((p) {
                  final isSelected = _selectedPeriod == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _selectPeriod(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.success
                              : AppColors.successBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.success
                                : AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          p,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // KPI Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                AdminStatCard(
                  title: 'Tổng doanh thu',
                  value: _analytics != null
                      ? _formatVnd(_analytics!.totalRevenue)
                      : '—',
                  icon: Icons.monetization_on_outlined,
                  color: AppColors.success,
                  isLoading: _isLoading,
                ),
                AdminStatCard(
                  title: 'Tỷ lệ hoàn thành',
                  value: _analytics != null
                      ? '${_analytics!.completionRate.toStringAsFixed(1)}%'
                      : '—',
                  icon: Icons.check_circle_outline,
                  color: AppColors.primary,
                  isLoading: _isLoading,
                ),
                AdminStatCard(
                  title: 'Cuốc xe ôm',
                  value: _analytics != null
                      ? '${_analytics!.totalRides}'
                      : '—',
                  subtitle: '${_analytics?.completedRides ?? 0} hoàn thành',
                  icon: Icons.motorcycle,
                  color: AppColors.accent,
                  isLoading: _isLoading,
                ),
                AdminStatCard(
                  title: 'Đơn giao hàng',
                  value: _analytics != null
                      ? '${_analytics!.totalDeliveries}'
                      : '—',
                  subtitle: '${_analytics?.completedDeliveries ?? 0} hoàn thành',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.secondary,
                  isLoading: _isLoading,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Doanh thu biểu đồ
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Doanh thu theo ngày',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : SimpleRevenueChart(
                            data: _dailyRevenue
                                .map((d) {
                                  final parts = d.date.split('-');
                                  final label =
                                      '${parts[2]}/${parts[1]}';
                                  return MapEntry(label, d.revenue);
                                })
                                .toList(),
                            maxRevenue: _dailyRevenue.isEmpty
                                ? 1
                                : _dailyRevenue
                                    .map((d) => d.revenue)
                                    .reduce(
                                        (a, b) => a > b ? a : b),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pie chart thay thế - dùng số liệu
            if (_analytics != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân bổ đơn hàng',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AnalyticsLegendRow(
                        label: 'Hoàn thành',
                        count: _analytics!.completedOrders,
                        total: _analytics!.totalOrders,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 10),
                      _AnalyticsLegendRow(
                        label: 'Đã hủy',
                        count: _analytics!.cancelledOrders,
                        total: _analytics!.totalOrders,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 10),
                      _AnalyticsLegendRow(
                        label: 'Đang xử lý',
                        count: _analytics!.totalOrders -
                            _analytics!.completedOrders -
                            _analytics!.cancelledOrders,
                        total: _analytics!.totalOrders,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Additional stats
            if (_analytics != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Số liệu người dùng & Tài xế',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 16),
                      _StatRow(
                        icon: Icons.person_add_outlined,
                        label: 'Người dùng mới trong kỳ',
                        value: '${_analytics!.newUsers} người',
                        color: AppColors.accent,
                      ),
                      _StatRow(
                        icon: Icons.motorcycle,
                        label: 'Tài xế đang hoạt động',
                        value: '${_analytics!.activeDrivers} tài xế',
                        color: AppColors.primary,
                      ),
                      _StatRow(
                        icon: Icons.attach_money,
                        label: 'Doanh thu xe ôm',
                        value: _formatVnd(_analytics!.totalRideRevenue),
                        color: AppColors.primary,
                      ),
                      _StatRow(
                        icon: Icons.local_shipping_outlined,
                        label: 'Doanh thu giao hàng',
                        value: _formatVnd(_analytics!.totalDeliveryRevenue),
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatVnd(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}T đ';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M đ';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k đ';
    return '${value.toStringAsFixed(0)} đ';
  }
}

class _AnalyticsLegendRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _AnalyticsLegendRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Text(
              '$count đơn (${(ratio * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
