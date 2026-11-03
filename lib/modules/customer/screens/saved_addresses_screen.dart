import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/network/openroute_client.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_logger.dart';
import '../../../models/saved_address_model.dart';
import '../services/customer_service.dart';

/// Màn hình Quản lý Danh bạ Địa chỉ Quen thuộc (Task 1.7)
/// Cho phép thêm, sửa, xóa các địa chỉ Nhà riêng / Cơ quan để đặt xe 1 chạm
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final String _userId = FirebaseService.currentUserId ?? '';

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

  void _showAddAddressDialog() {
    AddressLabel selectedLabel = AddressLabel.home;
    final addressController = TextEditingController();
    LatLng? selectedLatLng;
    bool isSearching = false;
    List<PlaceResult> searchResults = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomInset + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Thêm Địa Chỉ Mới',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Chọn nhãn (Home, Work, Other)
                    Text(
                      'Loại địa chỉ:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildLabelChoice(
                          label: AddressLabel.home,
                          current: selectedLabel,
                          icon: Icons.home_rounded,
                          title: 'Nhà riêng',
                          onTap: () =>
                              setSheetState(() => selectedLabel = AddressLabel.home),
                        ),
                        const SizedBox(width: 8),
                        _buildLabelChoice(
                          label: AddressLabel.work,
                          current: selectedLabel,
                          icon: Icons.business_rounded,
                          title: 'Cơ quan',
                          onTap: () =>
                              setSheetState(() => selectedLabel = AddressLabel.work),
                        ),
                        const SizedBox(width: 8),
                        _buildLabelChoice(
                          label: AddressLabel.other,
                          current: selectedLabel,
                          icon: Icons.location_on_rounded,
                          title: 'Khác',
                          onTap: () =>
                              setSheetState(() => selectedLabel = AddressLabel.other),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Ô tìm kiếm địa chỉ
                    Text(
                      'Địa chỉ cụ thể:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tên đường, địa danh để tìm kiếm...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.my_location,
                              color: AppColors.primary),
                          tooltip: 'Lấy vị trí GPS hiện tại',
                          onPressed: () async {
                            try {
                              setSheetState(() => isSearching = true);
                              final pos = await Geolocator.getCurrentPosition();
                              selectedLatLng = LatLng(pos.latitude, pos.longitude);
                              final reverseName = await OpenRouteClient.reverseGeocode(
                                  pos.latitude, pos.longitude);
                              addressController.text = reverseName ??
                                  'Tọa độ: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
                              setSheetState(() => isSearching = false);
                            } catch (_) {
                              setSheetState(() => isSearching = false);
                            }
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (val) async {
                        if (val.trim().length >= 3) {
                          setSheetState(() => isSearching = true);
                          final res = await OpenRouteClient.searchPlaces(
                            val,
                            userLat: selectedLatLng?.latitude,
                            userLng: selectedLatLng?.longitude,
                          );
                          setSheetState(() {
                            searchResults = res;
                            isSearching = false;
                          });
                        } else {
                          setSheetState(() => searchResults = []);
                        }
                      },
                    ),

                    if (isSearching) ...[
                      const SizedBox(height: 12),
                      const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],

                    // Kết quả gợi ý địa điểm
                    if (searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardDark
                              : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final place = searchResults[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on,
                                  color: AppColors.primary, size: 18),
                              title: Text(
                                place.displayName,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                addressController.text = place.displayName;
                                selectedLatLng =
                                    LatLng(place.latitude, place.longitude);
                                setSheetState(() => searchResults = []);
                              },
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Nút Lưu địa chỉ
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final text = addressController.text.trim();
                          if (text.isEmpty) {
                            AppDialogs.showError(ctx,
                                title: 'Thiếu Thông Tin',
                                message: 'Vui lòng nhập địa chỉ cụ thể.');
                            return;
                          }

                          final lat = selectedLatLng?.latitude ?? 21.0285;
                          final lng = selectedLatLng?.longitude ?? 105.8542;

                          try {
                            await CustomerService.instance.addSavedAddress(
                              userId: _userId,
                              label: selectedLabel,
                              addressText: text,
                              lat: lat,
                              lng: lng,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              AppDialogs.showSuccess(context,
                                  title: 'Thành Công',
                                  message: 'Địa chỉ đã được lưu vào danh bạ!');
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              AppDialogs.showError(ctx,
                                  title: 'Lỗi', message: '$e');
                            }
                          }
                        },
                        child: const Text(
                          'Lưu Vào Danh Bạ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabelChoice({
    required AddressLabel label,
    required AddressLabel current,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isSelected = label == current;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppColors.primary : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Địa Chỉ Đã Lưu'),
        elevation: 0,
      ),
      body: StreamBuilder<List<SavedAddressModel>>(
        stream: CustomerService.instance.streamSavedAddresses(_userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded,
                      size: 64, color: AppColors.primary.withAlpha(120)),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có địa chỉ nào được lưu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lưu Nhà riêng hoặc Cơ quan để đặt xe siêu tốc 1 chạm!',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showAddAddressDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm Địa Chỉ Đầu Tiên'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final addr = addresses[index];
              final icon = _getIconForLabel(addr.label);
              final labelName = _getTextForLabel(addr.label);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            addr.addressText,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error, size: 20),
                      tooltip: 'Xóa địa chỉ',
                      onPressed: () async {
                        final confirm = await AppDialogs.showConfirm(
                          context,
                          title: 'Xóa Địa Chỉ',
                          message:
                              'Bạn có chắc chắn muốn xóa "$labelName" khỏi danh bạ?',
                          confirmText: 'Xóa',
                          cancelText: 'Hủy',
                        );
                        if (confirm == true) {
                          await CustomerService.instance
                              .deleteSavedAddress(_userId, addr.id);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAddressDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Thêm Địa Chỉ'),
      ),
    );
  }
}

