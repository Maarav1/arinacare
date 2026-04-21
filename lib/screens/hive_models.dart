// lib/hive_models.dart
import 'package:hive/hive.dart';
import 'dart:typed_data';


part 'hive_models.g.dart';

@HiveType(typeId: 0)
class ChatMessageHive extends HiveObject {
  @HiveField(0)
  String text = '';
  
  @HiveField(1)
  bool isUser = false;
  
  @HiveField(2)
  DateTime timestamp = DateTime.now();
  
  @HiveField(3)
  bool isError = false;
  
  @HiveField(4)
  String modelUsed = '';
  
  @HiveField(5)
  String conversationId = '';
  
  // NEW FIELDS FOR THINKING MODE
  @HiveField(6)
  String? thinkingProcess;
  
  @HiveField(7)
  int? thinkingTimeMs;

   @HiveField(8)
  List<Uint8List>? imageBytes;

  @HiveField(9) // Add this new field
  bool? isIncomplete;
  
  // Constructor with all fields (including new ones)
  ChatMessageHive({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    required this.modelUsed,
    required this.conversationId,
    this.thinkingProcess,
    this.thinkingTimeMs,
    this.imageBytes,
    this.isIncomplete,
  });
}

@HiveType(typeId: 1)
class ConversationHive extends HiveObject {
  @HiveField(0)
  String id = '';
  
  @HiveField(1)
  DateTime lastMessageTimestamp = DateTime.now();
  
  @HiveField(2)
  int messageCount = 0;
  
  @HiveField(3)
  String modelUsed = '';
  
  ConversationHive();
}

@HiveType(typeId: 2)
class UserProfileHive extends HiveObject {
  @HiveField(0)
  String name = '';
  
  @HiveField(1)
  String interests = '';
  
  @HiveField(2)
  DateTime createdAt = DateTime.now();
  
  @HiveField(3)
  DateTime updatedAt = DateTime.now();
  
  UserProfileHive();
}