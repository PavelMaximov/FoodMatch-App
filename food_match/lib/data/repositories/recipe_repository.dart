import '../../core/constants/api_constants.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';

class RecipeRepository {
  RecipeRepository(this._apiService);

  final ApiService _apiService;

  Future<Recipe> getRecipe(String dishId) async {
    final data = await _apiService.get('${ApiConstants.recipes}/$dishId');
    return Recipe.fromJson(Map<String, dynamic>.from(data));
  }
}
