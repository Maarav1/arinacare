// lib/features/browser/domain/models/engagement_metrics.dart
import 'package:hive/hive.dart';

part 'engagement_metrics.g.dart';

@HiveType(typeId: 102)
class EngagementMetrics extends HiveObject {
  @HiveField(0)
  final String date; // YYYY-MM-DD format
  
  @HiveField(1)
  int searches = 0;
  
  @HiveField(2)
  int pagesViewed = 0;
  
  @HiveField(3)
  int adImpressions = 0;
  
  @HiveField(4)
  int adClicks = 0;
  
  @HiveField(5)
  int sessionDuration = 0; // in seconds
  
  EngagementMetrics({required this.date});
  
  void incrementSearches() {
    searches++;
    save();
  }
  
  void incrementPagesViewed() {
    pagesViewed++;
    save();
  }
  
  void incrementAdImpressions() {
    adImpressions++;
    save();
  }
  
  void incrementAdClicks() {
    adClicks++;
    save();
  }
  
  void addSessionDuration(int seconds) {
    sessionDuration += seconds;
    save();
  }
}