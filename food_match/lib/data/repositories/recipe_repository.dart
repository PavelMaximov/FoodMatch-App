import '../../core/constants/api_constants.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';

class RecipeRepository {
  RecipeRepository(this._apiService);

  final ApiService _apiService;

  Future<Recipe> getRecipe(String dishId) async {
    final data = await _apiService.get('${ApiConstants.recipes}/$dishId');
    return Recipe.fromJson(_extractMap(data, fallbackKey: 'recipe'));
  }

  Map<String, dynamic> _extractMap(dynamic data, {required String fallbackKey}) {
    if (data is Map<String, dynamic>) {
      final raw = data[fallbackKey];
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      return data;
    }
    throw const FormatException('Unexpected recipe response format.');
  }
}
