import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/cloudinary_config.dart';

/// Các loại giấy tờ định danh tài xế eKYC
enum DriverKycDocType {
  /// Căn cước công dân - Mặt trước
  idCardFront,

  /// Căn cước công dân - Mặt sau
  idCardBack,

  /// Giấy phép lái xe (GPLX)
  license,
}

/// Dịch vụ Tải ảnh Lên Đám mây Cloudinary Toàn hệ thống JetPost
/// Hỗ trợ ký số an toàn (Signed Upload), phân loại thư mục tự động và tối ưu hóa CDN
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  // ===========================================================================
  // 1. CÁC HÀM NGHIỆP VỤ CHUYÊN BIỆT THEO KIẾN TRÚC JETPOST
  // ===========================================================================

  /// Tải Ảnh Đại diện Người dùng (User / Driver / Admin)
  /// - Lưu trữ tự động vào folder: `jetpost/avatars`
  /// - Tên tệp định danh duy nhất theo UID: `avatar_{userId}`
  /// - Trả về: Đường dẫn HTTPS Secure URL (hoặc null nếu lỗi)
  Future<String?> uploadAvatar({
    required dynamic imageFile, // Hỗ trợ File hoặc Uint8List
    required String userId,
  }) async {
    return _uploadImage(
      imageFile: imageFile,
      folder: CloudinaryConfig.avatarsFolder,
      publicId: 'avatar_$userId',
      fileName: 'avatar_$userId.jpg',
    );
  }

  /// Tải Ảnh Hồ sơ Định danh eKYC của Đối tác Tài xế
  /// - Lưu trữ tự động vào folder: `jetpost/drivers_ekyc`
  /// - Tên tệp: `{driverId}_{docType}_{timestamp}`
  /// - Phục vụ Admin phóng to thẩm định hồ sơ (Task 4.3 trong KeHoach.md)
  Future<String?> uploadDriverKyc({
    required dynamic imageFile,
    required String driverId,
    required DriverKycDocType docType,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final docTypeStr = _getDocTypeString(docType);
    final publicId = '${driverId}_${docTypeStr}_$timestamp';

    return _uploadImage(
      imageFile: imageFile,
      folder: CloudinaryConfig.driversKycFolder,
      publicId: publicId,
      fileName: '$publicId.jpg',
    );
  }

  /// Tải Ảnh Chụp Bằng chứng Giao hàng PoD (Proof of Delivery)
  /// - Lưu trữ tự động vào folder: `jetpost/deliveries_pod`
  /// - Tên tệp: `pod_{deliveryId}_{timestamp}`
  /// - Phục vụ người gửi/người nhận kiểm tra và Admin đối soát tranh chấp
  Future<String?> uploadDeliveryPod({
    required dynamic imageFile,
    required String deliveryId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final publicId = 'pod_${deliveryId}_$timestamp';

    return _uploadImage(
      imageFile: imageFile,
      folder: CloudinaryConfig.deliveriesPodFolder,
      publicId: publicId,
      fileName: '$publicId.jpg',
    );
  }

  /// Tải Ảnh Tùy biến vào bất kỳ thư mục con nào bên trong `jetpost/`
  Future<String?> uploadCustomImage({
    required dynamic imageFile,
    required String subFolder,
    String? publicId,
    String? fileName,
  }) async {
    final cleanSubFolder = subFolder.startsWith('/') ? subFolder.substring(1) : subFolder;
    final targetFolder = '${CloudinaryConfig.rootFolder}/$cleanSubFolder';

    return _uploadImage(
      imageFile: imageFile,
      folder: targetFolder,
      publicId: publicId,
      fileName: fileName,
    );
  }

  // ===========================================================================
  // 2. ĐỘNG CƠ UPLOAD & KÝ SỐ BẢO MẬT (SIGNED UPLOAD ENGINE)
  // ===========================================================================

  Future<String?> _uploadImage({
    required dynamic imageFile,
    required String folder,
    String? publicId,
    String? fileName,
  }) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

      // Tập hợp các tham số cần ký số theo chuẩn Cloudinary
      final params = <String, String>{
        'folder': folder,
        'timestamp': timestamp,
      };

      if (publicId != null && publicId.trim().isNotEmpty) {
        params['public_id'] = publicId.trim();
      }

      // 1. Sắp xếp các tham số theo thứ tự alphabet
      final sortedKeys = params.keys.toList()..sort();
      final queryString = sortedKeys.map((k) => '$k=${params[k]}').join('&');

      // 2. Tạo chữ ký SHA-1: hash(queryString + apiSecret)
      final toSign = '$queryString${CloudinaryConfig.apiSecret}';
      final signature = sha1.convert(utf8.encode(toSign)).toString();

      // 3. Khởi tạo Multipart Request
      final uri = Uri.parse(CloudinaryConfig.uploadApiUrl);
      final request = http.MultipartRequest('POST', uri);

      // Điền các trường xác thực
      request.fields['api_key'] = CloudinaryConfig.apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['folder'] = folder;
      request.fields['signature'] = signature;
      if (publicId != null && publicId.trim().isNotEmpty) {
        request.fields['public_id'] = publicId.trim();
      }

      // 4. Gắn tệp ảnh nhị phân (hỗ trợ cả File di động lẫn Uint8List)
      final defaultName = fileName ?? 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (imageFile is File) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: defaultName),
        );
      } else if (imageFile is Uint8List) {
        request.files.add(
          http.MultipartFile.fromBytes('file', imageFile, filename: defaultName),
        );
      } else {
        throw ArgumentError('imageFile phải là kiểu File hoặc Uint8List');
      }

      // 5. Gửi request và phân tích kết quả
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = json['secure_url'] as String?;
        debugPrint('[CloudinaryService] Upload thành công: $secureUrl');
        return secureUrl;
      } else {
        debugPrint(
          '[CloudinaryService] Lỗi upload (${response.statusCode}): ${response.body}',
        );
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('[CloudinaryService] Ngoại lệ khi tải ảnh lên Cloudinary: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }

  // ===========================================================================
  // 3. TIỆN ÍCH TỐI ƯU HÓA CDN (AUTO COMPRESSION & RESIZING VIA URL)
  // ===========================================================================

  /// Sinh đường dẫn ảnh đã qua xử lý nén tự động trên CDN của Cloudinary
  /// - `autoFormat`: Tự đổi sang định dạng WebP/AVIF siêu nhẹ cho di động
  /// - `autoQuality`: Tự tối ưu chất lượng giảm 70% dung lượng
  /// - `width`, `height`: Kích thước mong muốn (crop fill)
  String getOptimizedUrl(
    String originalUrl, {
    int? width,
    int? height,
    bool autoFormat = true,
    bool autoQuality = true,
  }) {
    if (!originalUrl.contains('res.cloudinary.com') || !originalUrl.contains('/upload/')) {
      return originalUrl; // Trả về nguyên bản nếu không phải URL Cloudinary
    }

    final transformations = <String>[];
    if (autoFormat) transformations.add('f_auto');
    if (autoQuality) transformations.add('q_auto');

    if (width != null && height != null) {
      transformations.add('c_fill,w_$width,h_$height');
    } else if (width != null) {
      transformations.add('w_$width');
    } else if (height != null) {
      transformations.add('h_$height');
    }

    if (transformations.isEmpty) return originalUrl;

    final transformStr = transformations.join(',');
    return originalUrl.replaceFirst('/upload/', '/upload/$transformStr/');
  }

  String _getDocTypeString(DriverKycDocType docType) {
    switch (docType) {
      case DriverKycDocType.idCardFront:
        return 'cccd_front';
      case DriverKycDocType.idCardBack:
        return 'cccd_back';
      case DriverKycDocType.license:
        return 'gplx';
    }
  }
}
