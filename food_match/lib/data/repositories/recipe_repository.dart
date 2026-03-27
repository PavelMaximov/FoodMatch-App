import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';

class RecipeRepository {
  RecipeRepository(this._apiService);

  final ApiService _apiService;

  Future<Recipe> getRecipe(String dishId) async {
    final data = await _apiService.get('${ApiConstants.recipes}/$dishId');
    AppLogger.info('Response data: $data');
    if (data is Map<String, dynamic>) {
      final dynamic recipeData = data['recipe'] ?? data['dish']?['recipe'] ?? data;
      if (recipeData is Map<String, dynamic>) {
        return Recipe.fromJson(recipeData);
      }
    }
    throw const FormatException('Unexpected recipe response format.');
  }
}
