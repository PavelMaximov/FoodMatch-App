// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_swipe.dart';

class PendingSwipeAdapter extends TypeAdapter<PendingSwipe> {
  @override
  final int typeId = 1;

  @override
  PendingSwipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingSwipe(
      dishId: fields[0] as String,
      action: fields[1] as String,
      createdAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PendingSwipe obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.dishId)
      ..writeByte(1)
      ..write(obj.action)
      ..writeByte(2)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingSwipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
