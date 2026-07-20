// lib/hive_models.dart
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

part 'hive_models.g.dart';

@HiveType(typeId: 0)
class ChatMessageHive extends HiveObject {
  @HiveField(0)
  late String text;

  @HiveField(1)
  late bool isUser;

  @HiveField(2)
  late DateTime timestamp;

  @HiveField(3)
  late bool isError;

  @HiveField(4)
  late String? modelUsed;

  @HiveField(5)
  late String conversationId;

  @HiveField(6)
  String? thinkingProcess;

  @HiveField(7)
  int? thinkingTimeMs;

  @HiveField(8)
  List<Uint8List>? imageBytes;

  @HiveField(9)
  bool? isIncomplete;
}

@HiveType(typeId: 1)
class ConversationHive extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late DateTime lastMessageTimestamp;

  @HiveField(2)
  late int messageCount;

  @HiveField(3)
  late String modelUsed;
}

@HiveType(typeId: 2)
class UserProfileHive extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late String interests;

  @HiveField(2)
  late DateTime createdAt;

  @HiveField(3)
  late DateTime updatedAt;
}
