import '../../../../data/services/api_service.dart';
import '../domain/shopping_list_item.dart';

class SharedShoppingListRepository {
  SharedShoppingListRepository(this._api);
  final ApiService _api;

  Future<List<ShoppingListItem>> load() async => _items(await _api.get('/shopping-list/shared'));
  Future<List<ShoppingListItem>> add({required String name,String? quantity,String? measure}) async => _items(await _api.post('/shopping-list/shared/items',<String,dynamic>{'name':name,'quantity':quantity,'measure':measure}));
  Future<List<ShoppingListItem>> setChecked(String id,bool checked) async => _items(await _api.patch('/shopping-list/shared/items/$id',<String,dynamic>{'checked':checked}));
  Future<List<ShoppingListItem>> remove(String id) async => _items(await _api.delete('/shopping-list/shared/items/$id'));

  List<ShoppingListItem> _items(dynamic response){final map=Map<String,dynamic>.from(response as Map);return (map['items'] as List<dynamic>? ?? const <dynamic>[]).map((raw){final json=Map<String,dynamic>.from(raw as Map);return ShoppingListItem(id:'${json['id']}',name:'${json['name']}',normalizedName:'${json['normalized_name']??json['normalizedName']}',quantity:json['quantity']?.toString(),measure:json['measure']?.toString(),checked:json['checked']==true,sortOrder:(json['sort_order'] as num?)?.toInt()??0,createdAt:DateTime.tryParse('${json['created_at']}')??DateTime.now(),updatedAt:DateTime.tryParse('${json['updated_at']}')??DateTime.now());}).toList();}
}
