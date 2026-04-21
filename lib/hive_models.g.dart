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
    return ChatMessageHive()
      ..text = fields[0] as String
      ..isUser = fields[1] as bool
      ..timestamp = fields[2] as DateTime
      ..isError = fields[3] as bool
      ..modelUsed = fields[4] as String?
      ..conversationId = fields[5] as String;
  }

  @override
  void write(BinaryWriter writer, ChatMessageHive obj) {
    writer
      ..writeByte(6)
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
      ..write(obj.conversationId);
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
