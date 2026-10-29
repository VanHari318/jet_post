import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _dailyRevenue = daily;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _exportReport() {
    if (_analytics == null) return;
    final a = _analytics!;
    final reportText = '''
BÁO CÁO KINH DOANH HỆ THỐNG JETPOST
Kỳ báo cáo: $_selectedPeriod (${_fromDate.day}/${_fromDate.month}/${_fromDate.year} - ${_toDate.day}/${_toDate.month}/${_toDate.year})
-----------------------------------------
1. Tổng doanh thu hoa hồng: ${a.totalRevenue.toStringAsFixed(0)} VNĐ
   - Doanh thu Xe ôm: ${a.totalRideRevenue.toStringAsFixed(0)} VNĐ
   - Doanh thu Giao hàng: ${a.totalDeliveryRevenue.toStringAsFixed(0)} VNĐ
2. Tổng số đơn hàng: ${a.totalOrders} đơn
   - Hoàn thành: ${a.completedOrders} đơn (${a.completionRate.toStringAsFixed(1)}%)
   - Đã hủy: ${a.cancelledOrders} đơn
3. Quy mô vận hành:
   - Tài xế đang hoạt động: ${a.activeDrivers} đối tác
   - Người dùng đăng ký mới: ${a.newUsers} tài khoản
''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: AppColors.success),
            SizedBox(width: 8),
            Expanded(child: Text('Xuất Báo cáo Kinh doanh')),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              reportText.trim(),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reportText.trim()));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📋 Đã sao chép dữ liệu báo cáo vào bộ nhớ tạm!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Sao chép báo cáo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
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
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Xuất báo cáo',
            onPressed: _analytics == null ? null : _exportReport,
          ),
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
                                : AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          p,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                isSelected ? Colors.white : AppColors.success,
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
                  subtitle:
                      '${_analytics?.completedDeliveries ?? 0} hoàn thành',
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
                      'Biểu đồ doanh thu theo ngày',
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
                            data: _dailyRevenue.map((d) {
                              final parts = d.date.split('-');
                              final label = '${parts[2]}/${parts[1]}';
                              return MapEntry(label, d.revenue);
                            }).toList(),
                            maxRevenue: _dailyRevenue.isEmpty
                                ? 1
                                : _dailyRevenue
                                    .map((d) => d.revenue)
                                    .reduce((a, b) => a > b ? a : b),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Biểu đồ tròn & Tỷ lệ đơn hàng (Task 4.7)
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
                        'Biểu đồ tròn: Tỷ lệ hoàn thành vs Hủy đơn',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: CustomPaint(
                              painter: _OrderPieChartPainter(
                                completed: _analytics!.completedOrders,
                                cancelled: _analytics!.cancelledOrders,
                                pending: (_analytics!.totalOrders -
                                        _analytics!.completedOrders -
                                        _analytics!.cancelledOrders)
                                    .clamp(0, 999999),
                              ),
                              child: Center(
                                child: Text(
                                  '${_analytics!.totalOrders}\nđơn',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
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
                                  count: (_analytics!.totalOrders -
                                          _analytics!.completedOrders -
                                          _analytics!.cancelledOrders)
                                      .clamp(0, 999999),
                                  total: _analytics!.totalOrders,
                                  color: AppColors.warning,
                                ),
                              ],
                            ),
                          ),
                        ],
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _exportReport,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Xuất dữ liệu báo cáo (Export Report)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

class _OrderPieChartPainter extends CustomPainter {
  final int completed;
  final int cancelled;
  final int pending;

  _OrderPieChartPainter({
    required this.completed,
    required this.cancelled,
    required this.pending,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = completed + cancelled + pending;
    final rect = Offset.zero & size;
    final strokeWidth = 16.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (total == 0) {
      paint.color = AppColors.borderLight;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        0,
        2 * math.pi,
        false,
        paint,
      );
      return;
    }

    double startAngle = -math.pi / 2;
    final segments = [
      MapEntry(completed, AppColors.success),
      MapEntry(cancelled, AppColors.error),
      MapEntry(pending, AppColors.warning),
    ];

    for (final seg in segments) {
      if (seg.key <= 0) continue;
      final sweep = (seg.key / total) * 2 * math.pi;
      paint.color = seg.value;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _OrderPieChartPainter old) =>
      old.completed != completed ||
      old.cancelled != cancelled ||
      old.pending != pending;
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
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
            Text(
              '$count (${(ratio * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 12,
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
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
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
              color: color.withValues(alpha: 0.1),
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
