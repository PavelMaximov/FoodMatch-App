import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/shopping_list/data/shared_shopping_list_repository.dart';
import 'package:food_match/features/shopping_list/data/shopping_list_storage.dart';
import 'package:food_match/features/shopping_list/domain/shopping_list_item.dart';
import 'package:food_match/features/shopping_list/logic/shopping_list_provider.dart';

ShoppingListItem _item(String id, [int sortOrder = 0]) => ShoppingListItem(
  id: id,
  name: id,
  normalizedName: id,
  checked: false,
  sortOrder: sortOrder,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Storage extends ShoppingListStorage {
  int loads = 0, saves = 0;
  Future<List<ShoppingListItem>> Function()? loader;
  @override
  Future<List<ShoppingListItem>> load() async {
    loads++;
    return loader == null ? [] : await loader!();
  }

  @override
  Future<void> save(List<ShoppingListItem> items) async {
    saves++;
  }
}

class _Shared implements SharedShoppingListRepository {
  final loads = <Completer<List<ShoppingListItem>>>[];
  final reorders = <Completer<List<ShoppingListItem>>>[];
  final orders = <List<String>>[];
  @override
  Future<List<ShoppingListItem>> load() {
    final c = Completer<List<ShoppingListItem>>();
    loads.add(c);
    return c.future;
  }

  @override
  Future<List<ShoppingListItem>> reorder(List<String> ids) {
    orders.add(ids);
    final c = Completer<List<ShoppingListItem>>();
    reorders.add(c);
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('stale old-pair load is ignored', () async {
    final shared = _Shared(), storage = _Storage();
    final provider = ShoppingListProvider(
      storage: storage,
      sharedRepository: shared,
    );
    addTearDown(provider.dispose);
    final a = provider.setSharedSession('a');
    final b = provider.setSharedSession('b');
    shared.loads[1].complete([_item('b')]);
    await b;
    shared.loads[0].complete([_item('a')]);
    await a;
    expect(provider.items.single.id, 'b');
    expect(storage.loads, 0);
  });
  test('late device-storage load cannot overwrite a shared list', () async {
    final pending = Completer<List<ShoppingListItem>>();
    final storage = _Storage()..loader = () => pending.future;
    final shared = _Shared();
    final provider = ShoppingListProvider(
      storage: storage,
      sharedRepository: shared,
    );
    addTearDown(provider.dispose);
    final local = provider.load();
    final pair = provider.setSharedSession('a');
    shared.loads.single.complete([_item('shared')]);
    await pair;
    pending.complete([_item('personal')]);
    await local;
    expect(provider.items.single.id, 'shared');
  });
  test(
    'shared reorder applies backend order without reading or saving device storage',
    () async {
      final shared = _Shared(), storage = _Storage();
      final provider = ShoppingListProvider(
        storage: storage,
        sharedRepository: shared,
      );
      addTearDown(provider.dispose);
      final load = provider.setSharedSession('a');
      shared.loads.single.complete([_item('one'), _item('two', 1)]);
      await load;
      final reorder = provider.reorder(0, 2);
      await Future<void>.delayed(Duration.zero);
      expect(shared.orders.single, ['two', 'one']);
      expect(provider.items.first.id, 'one');
      shared.reorders.single.complete([_item('two'), _item('one', 1)]);
      await reorder;
      expect(provider.items.first.id, 'two');
      expect(storage.loads, 0);
      expect(storage.saves, 0);
    },
  );
  test('pair switch during reorder ignores old response', () async {
    final shared = _Shared(), storage = _Storage();
    final provider = ShoppingListProvider(
      storage: storage,
      sharedRepository: shared,
    );
    addTearDown(provider.dispose);
    final load = provider.setSharedSession('a');
    shared.loads.single.complete([_item('one'), _item('two', 1)]);
    await load;
    final reorder = provider.reorder(0, 2);
    await Future<void>.delayed(Duration.zero);
    final next = provider.setSharedSession('b');
    shared.loads.last.complete([_item('new-pair')]);
    await next;
    shared.reorders.single.complete([_item('two'), _item('one', 1)]);
    await reorder;
    expect(provider.items.single.id, 'new-pair');
    expect(storage.saves, 0);
  });
  test('failed shared reorder leaves authoritative list intact', () async {
    final shared = _Shared();
    final provider = ShoppingListProvider(
      storage: _Storage(),
      sharedRepository: shared,
    );
    addTearDown(provider.dispose);
    final load = provider.setSharedSession('a');
    shared.loads.single.complete([_item('one'), _item('two', 1)]);
    await load;
    final reorder = provider.reorder(0, 2);
    final expectation = expectLater(reorder, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    shared.reorders.single.completeError(StateError('scope mismatch'));
    await expectation;
    expect(provider.items.map((item) => item.id), ['one', 'two']);
  });
}
