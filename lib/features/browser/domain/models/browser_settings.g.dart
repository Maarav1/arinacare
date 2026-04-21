// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browser_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BrowserSettingsAdapter extends TypeAdapter<BrowserSettings> {
  @override
  final int typeId = 101;

  @override
  BrowserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BrowserSettings()
      ..showAds = fields[0] as bool
      ..defaultSearchEngine = fields[1] as String
      ..enableAdBlock = fields[2] as bool
      ..allowAnalytics = fields[3] as bool
      ..acceptTerms = fields[4] as bool
      ..termsAcceptedDate = fields[5] as DateTime?
      ..seenMonetizationDisclosure = fields[6] as bool
      ..desktopMode = fields[7] as bool
      ..javascriptEnabled = fields[8] as bool
      ..cookiesEnabled = fields[9] as bool
      ..userAgent = fields[10] as String;
  }

  @override
  void write(BinaryWriter writer, BrowserSettings obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.showAds)
      ..writeByte(1)
      ..write(obj.defaultSearchEngine)
      ..writeByte(2)
      ..write(obj.enableAdBlock)
      ..writeByte(3)
      ..write(obj.allowAnalytics)
      ..writeByte(4)
      ..write(obj.acceptTerms)
      ..writeByte(5)
      ..write(obj.termsAcceptedDate)
      ..writeByte(6)
      ..write(obj.seenMonetizationDisclosure)
      ..writeByte(7)
      ..write(obj.desktopMode)
      ..writeByte(8)
      ..write(obj.javascriptEnabled)
      ..writeByte(9)
      ..write(obj.cookiesEnabled)
      ..writeByte(10)
      ..write(obj.userAgent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowserSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
