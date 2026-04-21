// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browser_tab.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BrowserTabAdapter extends TypeAdapter<BrowserTab> {
  @override
  final int typeId = 100;

  @override
  BrowserTab read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BrowserTab(
      id: fields[0] as String,
      initialUrl: fields[1] as String?,
      isIncognito: fields[2] as bool,
      title: fields[5] as String?,
      faviconUrl: fields[6] as String?,
      scrollPosition: fields[7] as double,
    )
      ..createdAt = fields[3] as DateTime
      ..lastAccessedAt = fields[4] as DateTime;
  }

  @override
  void write(BinaryWriter writer, BrowserTab obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.initialUrl)
      ..writeByte(2)
      ..write(obj.isIncognito)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.lastAccessedAt)
      ..writeByte(5)
      ..write(obj.title)
      ..writeByte(6)
      ..write(obj.faviconUrl)
      ..writeByte(7)
      ..write(obj.scrollPosition);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowserTabAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
