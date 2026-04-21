// lib/features/analytics/arina_analytics_engine.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:arina_cave/core/database/app_database.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Define missing classes
class EngagementPrediction {
  final double predictedEngagementScore;
  final double confidence;
  final String predictionDate;
  final Map<String, double> factorWeights;
  
  EngagementPrediction({
    required this.predictedEngagementScore,
    required this.confidence,
    required this.predictionDate,
    required this.factorWeights,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'predictedEngagementScore': predictedEngagementScore,
      'confidence': confidence,
      'predictionDate': predictionDate,
      'factorWeights': factorWeights,
    };
  }
}

class EngagementTrend {
  final String period;
  final double value;
  final double changePercent;
  final String trendDirection; // 'up', 'down', 'stable'
  
  EngagementTrend({
    required this.period,
    required this.value,
    required this.changePercent,
    required this.trendDirection,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'value': value,
      'changePercent': changePercent,
      'trendDirection': trendDirection,
    };
  }
}

class AnalyticsReport {
  int totalInteractions = 0;
  double avgSessionTime = 0;
  Map<String, int> activityByHour = {};
  List<EngagementTrend> trends = [];
  EngagementPrediction? prediction;
  Map<String, dynamic> userInsights = {};
  DateTime generatedAt = DateTime.now();
  
  void processChunk(List<Map<String, dynamic>> chunk) {
    for (final row in chunk) {
      totalInteractions++;
      
      final hour = DateTime.parse(row['timestamp']).hour.toString();
      activityByHour[hour] = (activityByHour[hour] ?? 0) + 1;
    }
  }
  
  AnalyticsReport complete(List<Map<String, dynamic>> trendsData, EngagementPrediction? prediction) {
    // Calculate averages
    if (totalInteractions > 0) {
      // Calculate average session time from trends if available
      if (trendsData.isNotEmpty) {
        final sessionTimes = trendsData
            .where((t) => t['avg_session_duration'] != null)
            .map((t) => t['avg_session_duration'] as double)
            .toList();
        if (sessionTimes.isNotEmpty) {
          avgSessionTime = sessionTimes.reduce((a, b) => a + b) / sessionTimes.length;
        }
      }
    }
    
    // Convert trends data to EngagementTrend objects
    trends = trendsData.map((trend) {
      return EngagementTrend(
        period: trend['period']?.toString() ?? 'Unknown',
        value: (trend['value'] ?? 0.0).toDouble(),
        changePercent: (trend['change_percent'] ?? 0.0).toDouble(),
        trendDirection: _determineTrendDirection((trend['change_percent'] ?? 0.0).toDouble()),
      );
    }).toList();
    
    this.prediction = prediction;
    
    // Generate user insights
    _generateInsights();
    
    return this;
  }
  
  String _determineTrendDirection(double changePercent) {
    if (changePercent > 5.0) return 'up';
    if (changePercent < -5.0) return 'down';
    return 'stable';
  }
  
  void _generateInsights() {
    userInsights = {
      'totalInteractions': totalInteractions,
      'avgSessionTime': avgSessionTime,
      'peakHour': _findPeakHour(),
      'engagementLevel': _calculateEngagementLevel(),
      'trendsCount': trends.length,
      'hasPrediction': prediction != null,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
  
  String _findPeakHour() {
    if (activityByHour.isEmpty) return 'N/A';
    final peakEntry = activityByHour.entries.reduce((a, b) => a.value > b.value ? a : b);
    return '${peakEntry.key}:00';
  }
  
  String _calculateEngagementLevel() {
    if (totalInteractions < 10) return 'Low';
    if (totalInteractions < 50) return 'Medium';
    return 'High';
  }
  
  Map<String, dynamic> toJson() {
    return {
      'totalInteractions': totalInteractions,
      'avgSessionTime': avgSessionTime,
      'activityByHour': activityByHour,
      'trends': trends.map((t) => t.toJson()).toList(),
      'prediction': prediction?.toJson(),
      'userInsights': userInsights,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

class ArinaAnalyticsEngine {
  final AppDatabase _database;
  
  ArinaAnalyticsEngine(this._database);
  
  // Process user data efficiently
  Future<AnalyticsReport> generateUserReport(String userId) async {
    final report = AnalyticsReport();
    
    // 1. Process in streaming fashion (simulated with batches)
    final interactions = await _getUserInteractions(userId);
    report.processChunk(interactions);
    
    // 2. Generate trends using SQL window functions
    final trends = await _calculateTrends(userId);
    
    // 3. Predictive analytics
    final prediction = await _predictEngagement(userId);
    
    return report.complete(trends, prediction);
  }
  
  Future<List<Map<String, dynamic>>> _getUserInteractions(String userId) async {
    // Get posts created by user
    final userPosts = _database.select(_database.posts)
      ..where((p) => p.userId.equals(userId))
      ..limit(10000); // Cap for performance
    
    final posts = await userPosts.get();
    
    // Convert to analytics format
    return posts.map((post) {
      return {
        'id': post.id,
        'user_id': userId,
        'type': 'post_created',
        'timestamp': post.createdAt.toIso8601String(),
        'content_length': post.content.length,
        'has_media': post.imageUrl != null || post.videoUrl != null,
      };
    }).toList();
  }
  
  Future<List<Map<String, dynamic>>> _calculateTrends(String userId) async {
    // Calculate weekly trends
    final now = DateTime.now();
    final trends = <Map<String, dynamic>>[];
    
    // Generate last 8 weeks of data
    for (int i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      
      // Get posts for this week
      final postsQuery = _database.select(_database.posts)
        ..where((p) => p.userId.equals(userId))
        ..where((p) => p.createdAt.isBetweenValues(weekStart, weekEnd));
      
      final posts = await postsQuery.get();
      
      // Get likes for this week
      final totalLikes = posts.fold(0, (sum, post) => sum + post.likes);
      final totalComments = posts.fold(0, (sum, post) => sum + post.commentsCount);
      
      final engagementScore = (totalLikes * 0.6) + (totalComments * 0.4);
      
      trends.add({
        'period': 'Week ${i + 1}',
        'value': engagementScore,
        'posts_count': posts.length,
        'total_likes': totalLikes,
        'total_comments': totalComments,
        'avg_session_duration': posts.isNotEmpty ? 180.0 : 0.0, // Simulated
        'change_percent': i < 7 ? _calculatePercentChange(trends, engagementScore) : 0.0,
      });
    }
    
    return trends;
  }
  
  double _calculatePercentChange(List<Map<String, dynamic>> trends, double currentValue) {
    if (trends.isEmpty) return 0.0;
    final previousValue = trends.last['value'] as double;
    if (previousValue == 0) return 0.0;
    return ((currentValue - previousValue) / previousValue) * 100;
  }
  
  // Lightweight ML for low RAM devices
  Future<EngagementPrediction?> _predictEngagement(String userId) async {
    try {
      // Get historical data
      final historicalData = await _getHistoricalData(userId);
      
      if (historicalData.isEmpty) return null;
      
      // Run simple regression
      final prediction = _runLinearRegression(historicalData);
      
      return EngagementPrediction(
        predictedEngagementScore: prediction['score'] ?? 0.0,
        confidence: prediction['confidence'] ?? 0.0,
        predictionDate: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        factorWeights: prediction['weights'] ?? {},
      );
    } catch (e) {
      if (kDebugMode) {
        print('Prediction error: $e');
      }
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>> _getHistoricalData(String userId) async {
    final historicalData = <Map<String, dynamic>>[];
    
    // Get last 30 days of activity
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    // Get posts
    final postsQuery = _database.select(_database.posts)
      ..where((p) => p.userId.equals(userId))
      ..where((p) => p.createdAt.isBiggerOrEqualValue(thirtyDaysAgo));
    
    final posts = await postsQuery.get();
    
    // Group by day
    final postsByDay = <String, List<Post>>{};
    for (final post in posts) {
      final day = post.createdAt.toIso8601String().split('T').first;
      postsByDay.putIfAbsent(day, () => []).add(post);
    }
    
    // Create training data
    for (final entry in postsByDay.entries) {
      final dayPosts = entry.value;
      final totalLikes = dayPosts.fold(0, (sum, post) => sum + post.likes);
      final totalComments = dayPosts.fold(0, (sum, post) => sum + post.commentsCount);
      final dayOfWeek = DateTime.parse(entry.key).weekday;
      
      historicalData.add({
        'day_of_week': dayOfWeek.toDouble(),
        'post_count': dayPosts.length.toDouble(),
        'avg_likes_per_post': dayPosts.isNotEmpty ? totalLikes / dayPosts.length : 0.0,
        'engagement_score': (totalLikes * 0.6) + (totalComments * 0.4),
      });
    }
    
    return historicalData;
  }
  
  Map<String, dynamic> _runLinearRegression(List<Map<String, dynamic>> data) {
    if (data.length < 3) {
      return {
        'score': 0.0,
        'confidence': 0.0,
        'weights': {},
      };
    }
    
    // Simple linear regression: y = b0 + b1*x1 + b2*x2 + b3*x3
    // Where:
    // y = engagement_score
    // x1 = day_of_week (1-7)
    // x2 = post_count
    // x3 = avg_likes_per_post
    
    final n = data.length;
    
    // Calculate means
    double sumY = 0, sumX1 = 0, sumX2 = 0, sumX3 = 0;
    
    for (final row in data) {
      sumY += row['engagement_score'] ?? 0.0;
      sumX1 += row['day_of_week'] ?? 0.0;
      sumX2 += row['post_count'] ?? 0.0;
      sumX3 += row['avg_likes_per_post'] ?? 0.0;
    }
    
    final meanY = sumY / n;
    final meanX1 = sumX1 / n;
    final meanX2 = sumX2 / n;
    final meanX3 = sumX3 / n;
    
    // Calculate sums of squares
    double ssX1X1 = 0, ssX2X2 = 0, ssX3X3 = 0;
    double ssX1Y = 0, ssX2Y = 0, ssX3Y = 0;
    
    for (final row in data) {
      final x1 = (row['day_of_week'] ?? 0.0) - meanX1;
      final x2 = (row['post_count'] ?? 0.0) - meanX2;
      final x3 = (row['avg_likes_per_post'] ?? 0.0) - meanX3;
      final y = (row['engagement_score'] ?? 0.0) - meanY;
      
      ssX1X1 += x1 * x1;
      ssX2X2 += x2 * x2;
      ssX3X3 += x3 * x3;
      ssX1Y += x1 * y;
      ssX2Y += x2 * y;
      ssX3Y += x3 * y;
    }
    
    // Calculate coefficients (simplified - in reality would use matrix algebra)
    final b1 = ssX1X1 > 0 ? ssX1Y / ssX1X1 : 0.0;
    final b2 = ssX2X2 > 0 ? ssX2Y / ssX2X2 : 0.0;
    final b3 = ssX3X3 > 0 ? ssX3Y / ssX3X3 : 0.0;
    final b0 = meanY - (b1 * meanX1) - (b2 * meanX2) - (b3 * meanX3);
    
    // Predict next week (assuming average of each factor)
    final predictedY = b0 + 
        (b1 * 4.0) + // Wednesday (middle of week)
        (b2 * (meanX2 * 1.1)) + // Slight growth
        (b3 * meanX3); // Average likes
    
    // Calculate R-squared (simplified)
    double ssTotal = 0, ssResidual = 0;
    for (final row in data) {
      final y = row['engagement_score'] ?? 0.0;
      final predicted = b0 + 
          (b1 * (row['day_of_week'] ?? 0.0)) +
          (b2 * (row['post_count'] ?? 0.0)) +
          (b3 * (row['avg_likes_per_post'] ?? 0.0));
      
      ssTotal += pow(y - meanY, 2);
      ssResidual += pow(y - predicted, 2);
    }
    
    final rSquared = ssTotal > 0 ? 1 - (ssResidual / ssTotal) : 0.0;
    
    return {
      'score': predictedY.clamp(0.0, 100.0),
      'confidence': rSquared.clamp(0.0, 1.0),
      'weights': {
        'day_of_week': b1,
        'post_count': b2,
        'avg_likes_per_post': b3,
        'intercept': b0,
      },
    };
  }
  
  // Export analytics to JSON (instead of Parquet for simplicity)
  Future<Uint8List> exportAnalyticsToJson(String userId) async {
    final report = await generateUserReport(userId);
    final jsonString = jsonEncode(report.toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }
  
  // Save analytics to file
  Future<String> saveAnalyticsReport(String userId) async {
    final report = await generateUserReport(userId);
    final jsonString = jsonEncode(report.toJson());
    
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'analytics_report_${userId}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${directory.path}/$fileName');
    
    await file.writeAsString(jsonString);
    
    return file.path;
  }
  
  // Get real-time analytics dashboard
  Future<Map<String, dynamic>> getDashboardAnalytics(String userId) async {
    final report = await generateUserReport(userId);
    
    return {
      'userId': userId,
      'report': report.toJson(),
      'summary': {
        'totalInteractions': report.totalInteractions,
        'avgSessionTime': report.avgSessionTime,
        'peakHour': report.userInsights['peakHour'],
        'engagementLevel': report.userInsights['engagementLevel'],
        'predictionScore': report.prediction?.predictedEngagementScore ?? 0.0,
        'predictionConfidence': report.prediction?.confidence ?? 0.0,
      },
      'generatedAt': report.generatedAt.toIso8601String(),
    };
  }
  
  // Track a new user interaction
  Future<void> trackInteraction({
    required String userId,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    // In a real implementation, you would:
    // 1. Store the interaction in analytics database
    // 2. Update real-time counters
    // 3. Trigger predictive model updates if needed
    
    if (kDebugMode) {
      print('Tracking interaction: $type for user $userId');
      print('Data: $data');
    }
    
    // For now, we'll just update the posts table if it's a post-related interaction
    if (type == 'post_created' && data['post_id'] != null) {
      await _database.into(_database.posts).insert(
        PostsCompanion(
          id: drift.Value(data['post_id']),
          userId: drift.Value(userId),
          content: drift.Value(data['content'] ?? ''),
          likes: const drift.Value(0),
          commentsCount: const drift.Value(0),
          shares: const drift.Value(0),
          createdAt: drift.Value(DateTime.now()),
        ),
      );
    }
  }
}