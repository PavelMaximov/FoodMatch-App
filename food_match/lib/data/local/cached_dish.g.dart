// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_dish.dart';

class CachedDishAdapter extends TypeAdapter<CachedDish> {
  @override
  final int typeId = 0;

  @override
  CachedDish read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedDish(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      imageUrl: fields[3] as String,
      cuisine: fields[4] as String,
      tags: (fields[5] as List).cast<String>(),
      source: fields[6] as String,
      externalId: fields[7] as String?,
      createdBy: fields[8] as String?,
      recipeIngredientsJson: fields[9] as String?,
      recipeStepsJson: fields[10] as String?,
      cachedAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedDish obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.cuisine)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.source)
      ..writeByte(7)
      ..write(obj.externalId)
      ..writeByte(8)
      ..write(obj.createdBy)
      ..writeByte(9)
      ..write(obj.recipeIngredientsJson)
      ..writeByte(10)
      ..write(obj.recipeStepsJson)
      ..writeByte(11)
      ..write(obj.cachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedDishAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
