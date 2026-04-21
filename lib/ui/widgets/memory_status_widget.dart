// lib/ui/widgets/memory_status_widget.dart
import 'package:flutter/material.dart';
import 'package:arina_cave/core/memory/memory_manager.dart';

class MemoryStatusDisplay extends StatelessWidget {
  final MemoryPressureLevel pressure;
  final Map<String, dynamic>? memoryInfo;
  final VoidCallback onRefresh;
  final VoidCallback onCleanup;
  
  const MemoryStatusDisplay({
    super.key,
    required this.pressure,
    this.memoryInfo,
    required this.onRefresh,
    required this.onCleanup,
  });
  
  Color _getPressureColor() {
    switch (pressure) {
      case MemoryPressureLevel.low: return Colors.green;
      case MemoryPressureLevel.medium: return Colors.orange;
      case MemoryPressureLevel.high: return Colors.deepOrange;
      case MemoryPressureLevel.critical: return Colors.red;
      default: return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getPressureColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Memory: ${pressure.toString().split('.').last.toUpperCase()}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: onRefresh,
                  iconSize: 20,
                ),
              ],
            ),
            
            if (memoryInfo != null && memoryInfo!.isNotEmpty) ...[
              SizedBox(height: 8),
              Divider(height: 1),
              SizedBox(height: 8),
              
              if (memoryInfo!['availableMemMB'] != null)
                Text('Available: ${memoryInfo!['availableMemMB']} MB'),
              
              if (memoryInfo!['totalMemMB'] != null)
                Text('Total: ${memoryInfo!['totalMemMB']} MB'),
                
              if (memoryInfo!['usedPercentage'] != null)
                Text('Used: ${memoryInfo!['usedPercentage'].toStringAsFixed(1)}%'),
            ],
            
            if (pressure == MemoryPressureLevel.critical) ...[
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: onCleanup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Clean Memory Now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}