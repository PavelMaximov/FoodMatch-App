class FilterConfig {
  const FilterConfig({
    required this.cuisines,
    required this.moods,
    required this.blocked,
    required this.diet,
    this.maxCookTime,
  });

  final List<String> cuisines;
  final List<String> moods;
  final List<String> blocked;
  final List<String> diet;
  final int? maxCookTime;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cuisines': cuisines,
        'moods': moods,
        'blocked': blocked,
        'diet': diet,
        'maxCookTime': maxCookTime,
      };

  factory FilterConfig.fromJson(Map<dynamic, dynamic> json) => FilterConfig(
        cuisines: List<String>.from(json['cuisines'] as List<dynamic>? ?? <dynamic>[]),
        moods: List<String>.from(json['moods'] as List<dynamic>? ?? <dynamic>[]),
        blocked: List<String>.from(json['blocked'] as List<dynamic>? ?? <dynamic>[]),
        diet: List<String>.from(json['diet'] as List<dynamic>? ?? <dynamic>[]),
        maxCookTime: json['maxCookTime'] as int?,
      );
}
