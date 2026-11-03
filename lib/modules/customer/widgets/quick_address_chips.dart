import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../models/saved_address_model.dart';
import '../../../routes/app_routes.dart';
import '../services/customer_service.dart';

/// Thanh phím chọn nhanh địa chỉ quen thuộc (Quick Action Chips)
/// Cho phép khách hàng chọn nhanh Nhà riêng / Cơ quan chỉ với 1 chạm
class QuickAddressChips extends StatelessWidget {
  final String userId;
  final void Function(SavedAddressModel address) onAddressSelected;

  const QuickAddressChips({
    super.key,
    required this.userId,
    required this.onAddressSelected,
  });

  IconData _getIconForLabel(AddressLabel label) {
    switch (label) {
      case AddressLabel.home:
        return Icons.home_rounded;
      case AddressLabel.work:
        return Icons.business_rounded;
      case AddressLabel.other:
        return Icons.location_on_rounded;
    }
  }

  String _getTextForLabel(AddressLabel label) {
    switch (label) {
      case AddressLabel.home:
        return 'Nhà riêng';
      case AddressLabel.work:
        return 'Cơ quan';
      case AddressLabel.other:
        return 'Địa chỉ khác';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<SavedAddressModel>>(
      stream: CustomerService.instance.streamSavedAddresses(userId),
      builder: (context, snapshot) {
        final addresses = snapshot.data ?? [];

        return SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ...addresses.map((addr) {
                final icon = _getIconForLabel(addr.label);
                final title = addr.addressText.isNotEmpty
                    ? (addr.addressText.length > 20
                        ? '${addr.addressText.substring(0, 18)}...'
                        : addr.addressText)
                    : _getTextForLabel(addr.label);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(icon, color: AppColors.primary, size: 16),
                    label: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    backgroundColor: isDark
                        ? AppColors.cardDark
                        : AppColors.cardLight,
                    side: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => onAddressSelected(addr),
                  ),
                );
              }),

              // Nút Thêm địa chỉ mới
              ActionChip(
                avatar: const Icon(Icons.add, color: AppColors.primary, size: 16),
                label: Text(
                  'Thêm địa chỉ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                backgroundColor: isDark
                    ? AppColors.surfaceDark
                    : AppColors.backgroundLight,
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  style: BorderStyle.solid,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.savedAddresses);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

