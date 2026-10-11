import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/shopping_list/data/shared_shopping_list_repository.dart';
import 'package:food_match/features/shopping_list/data/shopping_list_storage.dart';
import 'package:food_match/features/shopping_list/domain/shopping_list_item.dart';
import 'package:food_match/features/shopping_list/logic/shopping_list_provider.dart';

class _Storage extends ShoppingListStorage {
  int saves=0;
  @override Future<List<ShoppingListItem>> load() async=><ShoppingListItem>[];
  @override Future<void> save(List<ShoppingListItem> items) async{saves++;}
}
class _Shared implements SharedShoppingListDataSource {
  final loads=<Completer<List<ShoppingListItem>>>[];int reorders=0;Completer<List<ShoppingListItem>>? reorderRequest;
  @override Future<List<ShoppingListItem>> load(){final value=Completer<List<ShoppingListItem>>();loads.add(value);return value.future;}
  @override Future<List<ShoppingListItem>> reorder(List<String> ids){reorders++;if(reorderRequest!=null)return reorderRequest!.future;return Future.value(ids.reversed.map(_item).toList());}
  @override Future<List<ShoppingListItem>> add({required String name,String? quantity,String? measure})async=>[];
  @override Future<List<ShoppingListItem>> remove(String id)async=>[];
  @override Future<List<ShoppingListItem>> setChecked(String id,bool checked)async=>[];
}
ShoppingListItem _item(String id)=>ShoppingListItem(id:id,name:id,normalizedName:id,checked:false,sortOrder:0,createdAt:DateTime(2026),updatedAt:DateTime(2026));

void main(){
 test('old pair response cannot populate a new pair scope',()async{final remote=_Shared(),provider=ShoppingListProvider(sharedRepository:remote);final old=provider.setSharedSession('old');final next=provider.setSharedSession('new');remote.loads[1].complete([_item('new-item')]);await next;remote.loads[0].complete([_item('old-item')]);await old;expect(provider.items.single.id,'new-item');});
 test('shared reorder is authoritative and never writes local storage',()async{final remote=_Shared(),storage=_Storage(),provider=ShoppingListProvider(storage:storage,sharedRepository:remote);final load=provider.setSharedSession('pair');remote.loads.single.complete([_item('one'),_item('two')]);await load;await provider.reorder(0,2);expect(remote.reorders,1);expect(storage.saves,0);expect(provider.items.map((item)=>item.id),['one','two']);});
 test('pair switch invalidates in-flight reorder response',()async{final remote=_Shared()..reorderRequest=Completer<List<ShoppingListItem>>(),provider=ShoppingListProvider(sharedRepository:remote);final load=provider.setSharedSession('one');remote.loads.single.complete([_item('one'),_item('two')]);await load;final reorder=provider.reorder(0,2);final switched=provider.setSharedSession('two');remote.loads[1].complete([_item('current')]);await switched;remote.reorderRequest!.complete([_item('stale')]);await reorder;expect(provider.items.single.id,'current');});
}
