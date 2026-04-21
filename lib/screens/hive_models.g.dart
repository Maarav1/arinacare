// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageHiveAdapter extends TypeAdapter<ChatMessageHive> {
  @override
  final int typeId = 0;

  @override
  ChatMessageHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessageHive(
      text: fields[0] as String,
      isUser: fields[1] as bool,
      timestamp: fields[2] as DateTime,
      isError: fields[3] as bool,
      modelUsed: fields[4] as String,
      conversationId: fields[5] as String,
      thinkingProcess: fields[6] as String?,
      thinkingTimeMs: fields[7] as int?,
      imageBytes: (fields[8] as List?)?.cast<Uint8List>(),
      isIncomplete: fields[9] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessageHive obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.isUser)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.isError)
      ..writeByte(4)
      ..write(obj.modelUsed)
      ..writeByte(5)
      ..write(obj.conversationId)
      ..writeByte(6)
      ..write(obj.thinkingProcess)
      ..writeByte(7)
      ..write(obj.thinkingTimeMs)
      ..writeByte(8)
      ..write(obj.imageBytes)
      ..writeByte(9)
      ..write(obj.isIncomplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConversationHiveAdapter extends TypeAdapter<ConversationHive> {
  @override
  final int typeId = 1;

  @override
  ConversationHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationHive()
      ..id = fields[0] as String
      ..lastMessageTimestamp = fields[1] as DateTime
      ..messageCount = fields[2] as int
      ..modelUsed = fields[3] as String;
  }

  @override
  void write(BinaryWriter writer, ConversationHive obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.lastMessageTimestamp)
      ..writeByte(2)
      ..write(obj.messageCount)
      ..writeByte(3)
      ..write(obj.modelUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserProfileHiveAdapter extends TypeAdapter<UserProfileHive> {
  @override
  final int typeId = 2;

  @override
  UserProfileHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfileHive()
      ..name = fields[0] as String
      ..interests = fields[1] as String
      ..createdAt = fields[2] as DateTime
      ..updatedAt = fields[3] as DateTime;
  }

  @override
  void write(BinaryWriter writer, UserProfileHive obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.interests)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
