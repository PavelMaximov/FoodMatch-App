import 'dart:io';

import '../../core/constants/api_constants.dart';
import '../services/api_service.dart';

class AvatarUploadResult {
  const AvatarUploadResult({
    required this.avatarUrl,
    this.avatarPublicId,
  });

  final String avatarUrl;
  final String? avatarPublicId;

  factory AvatarUploadResult.fromJson(Map<String, dynamic> json) {
    final String? avatarUrl = json['avatarUrl'] as String?;
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      throw const ApiException('Upload response did not include an avatar URL.');
    }

    return AvatarUploadResult(
      avatarUrl: avatarUrl,
      avatarPublicId: json['avatarPublicId'] as String?,
    );
  }
}

class DishImageUploadResult {
  const DishImageUploadResult({
    required this.imageUrl,
    this.imagePublicId,
  });

  final String imageUrl;
  final String? imagePublicId;

  factory DishImageUploadResult.fromJson(Map<String, dynamic> json) {
    final String? imageUrl = json['imageUrl'] as String?;
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw const ApiException('Upload response did not include an image URL.');
    }

    return DishImageUploadResult(
      imageUrl: imageUrl,
      imagePublicId: json['imagePublicId'] as String?,
    );
  }
}

class UploadRepository {
  UploadRepository(this._apiService);

  final ApiService _apiService;

  Future<AvatarUploadResult> uploadAvatar(File file) async {
    final Map<String, dynamic> data = await _apiService.uploadFile(
      endpoint: ApiConstants.uploadAvatar,
      file: file,
    );
    return AvatarUploadResult.fromJson(data);
  }

  Future<void> deleteAvatar() async {
    await _apiService.delete(ApiConstants.uploadAvatar);
  }

  Future<DishImageUploadResult> uploadCustomDishImage(File file) async {
    final Map<String, dynamic> data = await _apiService.uploadFile(
      endpoint: ApiConstants.uploadCustomDishImage,
      file: file,
    );
    return DishImageUploadResult.fromJson(data);
  }

  Future<String> uploadImage(File file) async {
    final DishImageUploadResult result = await uploadCustomDishImage(file);
    return result.imageUrl;
  }
}
