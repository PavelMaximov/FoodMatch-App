enum PremiumEntryPoint {
  overview,
  advancedFilters,
  shoppingList,
  sessionHistory,
  customDishLimit;

  String get title => switch (this) {
    PremiumEntryPoint.advancedFilters => 'Unlock advanced filters',
    PremiumEntryPoint.shoppingList => 'Unlock shopping lists',
    PremiumEntryPoint.sessionHistory => 'Unlock session history',
    PremiumEntryPoint.customDishLimit => 'Create unlimited custom dishes',
    PremiumEntryPoint.overview => 'FoodMatch Premium',
  };

  String get subtitle => switch (this) {
    PremiumEntryPoint.advancedFilters => 'Find dishes by cooking time, calories, effort, ingredients and season.',
    PremiumEntryPoint.shoppingList => 'Plan ingredients, save your list and share it with your partner.',
    PremiumEntryPoint.sessionHistory => 'Revisit previous FoodMatch sessions and matches.',
    PremiumEntryPoint.customDishLimit => 'Free accounts can create up to 3 custom dishes. Upgrade for unlimited dishes.',
    PremiumEntryPoint.overview => 'Get more ways to plan, filter and revisit your FoodMatch experience.',
  };
}
