import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SimpleRevenueChart extends StatelessWidget {
  final List<MapEntry<String, double>> data;
  final double maxRevenue;

  const SimpleRevenueChart({
    super.key,
    required this.data,
    required this.maxRevenue,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có dữ liệu doanh thu trong khoảng thời gian này',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMutedLight),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: data.map((entry) {
              final ratio = maxRevenue > 0 ? entry.value / maxRevenue : 0.0;
              final barH = 120.0 * ratio;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatVnd(entry.value),
                    style:
                        const TextStyle(fontSize: 9, color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 28,
                    height: barH.clamp(4.0, 120.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.key,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondaryLight),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatVnd(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}
