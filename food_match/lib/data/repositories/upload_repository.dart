import 'dart:io';

import '../../core/constants/api_constants.dart';
import '../services/api_service.dart';

class UploadRepository {
  UploadRepository(this._apiService);

  final ApiService _apiService;

  Future<String> uploadImage(File file) async {
    final data = await _apiService.postMultipart(ApiConstants.uploads, file);
    return (data as Map<String, dynamic>)['url'] as String;
  }
}
