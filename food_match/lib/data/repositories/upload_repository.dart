import 'dart:io';

import '../../core/constants/api_constants.dart';
import '../services/api_service.dart';

class UploadRepository {
  UploadRepository(this._apiService);

  final ApiService _apiService;

  Future<String> uploadImage(File file) async {
    final data = await _apiService.postMultipart(ApiConstants.uploads, file);

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected upload response format.');
    }

    final url = data['url'];
    if (url is! String) {
      throw const FormatException('Upload response does not contain `url`.');
    }

    return url;
  }
}
