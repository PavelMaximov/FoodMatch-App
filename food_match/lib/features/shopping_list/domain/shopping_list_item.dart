class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.checked,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.quantity,
    this.measure,
    this.sourceDishId,
    this.sourceDishName,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String? quantity;
  final String? measure;
  final String? sourceDishId;
  final String? sourceDishName;
  final bool checked;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShoppingListItem copyWith({
    String? quantity,
    String? measure,
    bool? checked,
    int? sortOrder,
    DateTime? updatedAt,
  }) =>
      ShoppingListItem(
        id: id,
        name: name,
        normalizedName: normalizedName,
        quantity: quantity ?? this.quantity,
        measure: measure ?? this.measure,
        sourceDishId: sourceDishId,
        sourceDishName: sourceDishName,
        checked: checked ?? this.checked,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'normalizedName': normalizedName,
        'quantity': quantity,
        'measure': measure,
        'sourceDishId': sourceDishId,
        'sourceDishName': sourceDishName,
        'checked': checked,
        'sortOrder': sortOrder,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'] as String,
      name: json['name'] as String,
      normalizedName: json['normalizedName'] as String,
      quantity: json['quantity'] as String?,
      measure: json['measure'] as String?,
      sourceDishId: json['sourceDishId'] as String?,
      sourceDishName: json['sourceDishName'] as String?,
      checked: json['checked'] as bool,
      sortOrder: json['sortOrder'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
