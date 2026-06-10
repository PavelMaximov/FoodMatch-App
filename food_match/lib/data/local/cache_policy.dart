class CachePolicy {
  const CachePolicy._();

  static const Duration catalogDishesTtl = Duration(minutes: 20);
  static const Duration favoritesTtl = Duration(minutes: 3);
  static const Duration matchesTtl = Duration(seconds: 45);
  static const Duration authUserTtl = Duration(minutes: 5);
  static const Duration currentCoupleTtl = Duration(seconds: 30);
}
