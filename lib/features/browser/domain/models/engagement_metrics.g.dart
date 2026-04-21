// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'engagement_metrics.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EngagementMetricsAdapter extends TypeAdapter<EngagementMetrics> {
  @override
  final int typeId = 102;

  @override
  EngagementMetrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EngagementMetrics(
      date: fields[0] as String,
    )
      ..searches = fields[1] as int
      ..pagesViewed = fields[2] as int
      ..adImpressions = fields[3] as int
      ..adClicks = fields[4] as int
      ..sessionDuration = fields[5] as int;
  }

  @override
  void write(BinaryWriter writer, EngagementMetrics obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.searches)
      ..writeByte(2)
      ..write(obj.pagesViewed)
      ..writeByte(3)
      ..write(obj.adImpressions)
      ..writeByte(4)
      ..write(obj.adClicks)
      ..writeByte(5)
      ..write(obj.sessionDuration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngagementMetricsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
