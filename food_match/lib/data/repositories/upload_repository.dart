import 'dart:io';

import '../../core/constants/api_constants.dart';
import '../services/api_service.dart';

class UploadPreparation {
  const UploadPreparation({
    required this.uploadUrl,
    required this.objectKey,
    required this.mimeType,
    required this.sizeBytes,
    required this.headers,
  });

  final String uploadUrl;
  final String objectKey;
  final String mimeType;
  final int sizeBytes;
  final Map<String, String> headers;
}

class UploadRepository {
  UploadRepository(this._apiService);

  final ApiService _apiService;

  Future<UploadPreparation> prepareAvatarUpload(File file) async {
    return _prepareUpload(file: file, endpoint: ApiConstants.uploadsAvatarUrl);
  }

  Future<UploadPreparation> prepareDishImageUpload(File file) async {
    return _prepareUpload(file: file, endpoint: ApiConstants.uploadsDishImageUrl);
  }

  Future<void> uploadFileToSignedUrl({
    required String uploadUrl,
    required String mimeType,
    required File file,
    Map<String, String>? headers,
  }) async {
    final bytes = await file.readAsBytes();
    await _apiService.putToAbsoluteUrl(
      url: uploadUrl,
      bytes: bytes,
      contentType: mimeType,
      extraHeaders: headers,
    );
  }

  Future<void> confirmAvatarUpload({
    required String avatarKey,
    required String avatarMimeType,
    required int avatarSize,
  }) async {
    await _apiService.post(ApiConstants.usersAvatarConfirm, {
      'avatarKey': avatarKey,
      'avatarMimeType': avatarMimeType,
      'avatarSize': avatarSize,
    });
  }

  Future<void> deleteAvatar() async {
    await _apiService.delete(ApiConstants.usersAvatar);
  }

  Future<UploadPreparation> _prepareUpload({
    required File file,
    required String endpoint,
  }) async {
    final String mimeType = _guessMimeType(file.path);
    final int sizeBytes = await file.length();

    final data = await _apiService.post(endpoint, {
      'fileName': file.uri.pathSegments.isEmpty ? 'image' : file.uri.pathSegments.last,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    });

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected upload preparation response format.');
    }

    final String? uploadUrl = data['uploadUrl'] as String?;
    final String? objectKey = data['objectKey'] as String?;
    final dynamic rawHeaders = data['headers'];

    if (uploadUrl == null || objectKey == null) {
      throw const FormatException('Upload preparation response is missing uploadUrl/objectKey.');
    }

    final Map<String, String> headers = <String, String>{};
    if (rawHeaders is Map<String, dynamic>) {
      rawHeaders.forEach((key, value) {
        headers[key] = value.toString();
      });
    }

    return UploadPreparation(
      uploadUrl: uploadUrl,
      objectKey: objectKey,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      headers: headers,
    );
  }

  String _guessMimeType(String path) {
    final String ext = path.toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    if (ext.endsWith('.jpeg') || ext.endsWith('.jpg')) return 'image/jpeg';
    return 'image/jpeg';
  }
}
