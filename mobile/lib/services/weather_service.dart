// ignore_for_file: unused_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Hourly forecast model
@immutable
class HourlyForecast {
  final DateTime time;
  final double rainfallMM; // rainfall in mm for this hour

  const HourlyForecast({
    required this.time,
    required this.rainfallMM,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json, int index) {
    final timeStr = json['time'] as String?;
    final rainMM = json['rain'] is List ? ((json['rain'][index] as num?)?.toDouble() ?? 0.0) : 0.0;

    DateTime parsedTime;
    if (timeStr != null) {
      parsedTime = DateTime.parse(timeStr);
    } else {
      parsedTime = DateTime.now().add(Duration(hours: index));
    }

    return HourlyForecast(
      time: parsedTime,
      rainfallMM: rainMM >= 0 ? rainMM : 0.0,
    );
  }

  String get formattedTime => DateFormat('HH:mm').format(time);
  String get formattedDateTime => DateFormat('MMM dd • hh:mm').format(time);
}

/// Daily forecast model
@immutable
class DailyForecast {
  final DateTime date;
  final double rainfallSumMM; // total rainfall in mm for the day

  const DailyForecast({
    required this.date,
    required this.rainfallSumMM,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json, int index) {
    final dateStr = json['time'] as String?;
    final rainSumMM = json['rain_sum'] is List ? ((json['rain_sum'][index] as num?)?.toDouble() ?? 0.0) : 0.0;

    DateTime parsedDate;
    if (dateStr != null) {
      parsedDate = DateTime.parse(dateStr).toLocal();
    } else {
      parsedDate = DateTime.now().add(Duration(days: index));
    }

    return DailyForecast(
      date: parsedDate,
      rainfallSumMM: rainSumMM >= 0 ? rainSumMM : 0.0,
    );
  }

  String get formattedDate => DateFormat('MMM dd').format(date);
  String get formattedRainfall => rainfallSumMM > 0 ? '${rainfallSumMM.toStringAsFixed(1)} mm' : '0.0 mm';
}

/// Rain risk classification
enum RainRiskLevel { low, moderate, high, severe }

extension RainRiskLevelExtension on RainRiskLevel {
  String get label {
    switch (this) {
      case RainRiskLevel.low:
        return 'Low';
      case RainRiskLevel.moderate:
        return 'Moderate';
      case RainRiskLevel.high:
        return 'High';
      case RainRiskLevel.severe:
        return 'Severe';
    }
  }

  Color get color {
    switch (this) {
      case RainRiskLevel.low:
        return Colors.green;
      case RainRiskLevel.moderate:
        return Colors.amber;
      case RainRiskLevel.high:
        return Colors.orange;
      case RainRiskLevel.severe:
        return Colors.red;
    }
  }

  String get advice {
    switch (this) {
      case RainRiskLevel.low:
        return 'Monitor weather updates. No immediate action required.';
      case RainRiskLevel.moderate:
        return 'Prepare emergency kits. Stay alert for updates.';
      case RainRiskLevel.high:
        return 'Consider evacuation if in low-lying areas. Avoid flooded streets.';
      case RainRiskLevel.severe:
        return 'Evacuate immediately to designated safe zones. Follow authorities\' instructions.';
    }
  }
}

/// Calculates rain risk level based on accumulated rainfall
RainRiskLevel calculateRainRisk(double rainfallMM) {
  if (rainfallMM >= 50) return RainRiskLevel.severe;
  if (rainfallMM >= 25) return RainRiskLevel.high;
  if (rainfallMM >= 10) return RainRiskLevel.moderate;
  return RainRiskLevel.low;
}