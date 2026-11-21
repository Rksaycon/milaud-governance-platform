/// Repository responsible for fetching and aggregating raw weather data.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../features/rain_forecast/models/weather_data_models.dart';
import '../features/rain_forecast/models/weather_risk_models.dart';
import '../features/rain_forecast/risk/weather_risk_rules.dart';
import '../features/rain_forecast/types.dart';

/// Open-Meteo Forecast API base URL.
const String _openMeteoBase = 'https://api.open-meteo.com/v1/forecast';

const String _userAgent = 'may-laud-flutter/1.0';

/// Open-Meteo current-weather parameters (observations from the realtime layer).
const List<String> _currentTokens = <String>[
  'temperature_2m',
  'relative_humidity_2m',
  'weather_code',
  'wind_speed_10m',
  'precipitation',
];

/// Open-Meteo daily forecast parameters (7-day outlook).
const List<String> _dailyTokens = <String>[
  'temperature_2m_max',
  'temperature_2m_min',
  'precipitation_sum',
  'rain_sum',
  'showers_sum',
  'precipitation_probability_max',
  'weather_code',
  'wind_speed_10m_max',
];

/// Open-Meteo hourly forecast parameters.
const List<String> _hourlyTokens = <String>[
  'temperature_2m',
  'precipitation',
  'rain',
  'showers',
  'precipitation_probability',
  'weather_code',
  'wind_speed_10m',
];

/// Input that the repository can fetch in a single "snapshot".
@immutable
class WeatherSnapshot {
  final CurrentWeather? current;
  final List<WeatherDay> daily;
  final List<WeatherHour>? hourly;

  const WeatherSnapshot({
    this.current,
    required this.daily,
    this.hourly,
  });
}

/// Centralized access point for all weather data.
///
/// The repository is a thin, deterministic layer over the Open-Meteo Forecast
/// API. All values come straight from the API; missing fields are represented
/// as null — never fabricated. Network failures surface as a null return, never
/// as raw [DioException] or [SocketException], so the UI can show one
/// consistent "no data" state.
@immutable
class WeatherRepository {
  final Dio? _injectedDio;

  const WeatherRepository({Dio? dio}) : _injectedDio = dio;

  static final Dio _defaultDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {HttpHeaders.userAgentHeader: _userAgent},
    ),
  );

  Dio get _dio => _injectedDio ?? _defaultDio;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherRepository && _dio == other._dio;

  @override
  int get hashCode => _dio.hashCode;

  /// Fetches the raw forecast data for a location. Returns null when the
  /// location is unusable or the service fails. Never returns fabricated data.
  Future<WeatherForecastData?> fetchForecast(
    Location location,
  ) async {
    if (!LocationConfig.hasCoordinate(location.id)) {
      return null;
    }

    final query = <String, String>{
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'timezone': 'Asia/Manila',
      'current': _currentTokens.join(','),
      'daily': _dailyTokens.join(','),
      'hourly': _hourlyTokens.join(','),
    };

    final encoded = query.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final uri = Uri.parse('$_openMeteoBase?$encoded');

    final startedAt = DateTime.now().toIso8601String();
    String? finishedAt;

    try {
      final response = await _dio.get<Map<String, dynamic>>(uri.toString());
      final payload = response.data;

      if (payload == null) {
        return null;
      }

      finishedAt = DateTime.now().toIso8601String();

      final current =
          _parseCurrent(payload['current'] as Map<String, dynamic>?);
      final daily = _parseDaily(payload['daily'] as Map<String, dynamic>?);
      final hourly = _parseHourly(payload['hourly'] as Map<String, dynamic>?);

      return WeatherForecastData(
        location: location,
        sourceUrl: uri.toString(),
        callStartedAt: startedAt,
        callFinishedAt: finishedAt,
        current: current,
        daily: daily,
        hourly: hourly,
        raw: payload,
      );
    } on Exception {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Returns a snapshot structure for caching/UI.
  WeatherSnapshot asSnapshot(WeatherForecastData data) {
    return WeatherSnapshot(
      current: data.current,
      daily: data.daily,
      hourly: data.hourly,
    );
  }

  /// Builds a [FloodRiskSnapshot] from raw data without mutating anything.
  FloodRiskSnapshot buildSnapshot({
    required WeatherForecastData data,
    required bool isStale,
    required String staleSince,
    required OfficialFloodAdvisory? officialAdvisory,
    required WaterLevelReading? measuredWaterLevel,
    required WaterLevelForecast? predictedWaterLevel,
    required bool waterLevelSourceUnavailable,
  }) {
    final location = data.location;
    final currentWeather = data.current;
    final dailyRain = data.daily;
    final hourlyDetails = data.hourly;

    // Daily rain outlook summary (rainfall only).
    String? rainOutlookSummary;
    final anyRain = dailyRain.any((d) => d.hasRainfall) ||
        dailyRain.any((d) => d.precipitationProbabilityMaxPct != null);
    if (anyRain) {
      final maxProb = dailyRain
          .map((d) => d.precipitationProbabilityMaxPct)
          .whereType<int>()
          .reduce((a, b) => a > b ? a : b);
      final maxRain = dailyRain
          .map((d) => d.precipitationSumMm ?? d.rainSumMm ?? d.showersSumMm)
          .whereType<double>()
          .reduce((a, b) => a > b ? a : b);

      if (maxProb >= 80) {
        rainOutlookSummary =
            SummaryText.severeRain(locationName: location.displayName);
      } else if (maxProb >= 60) {
        rainOutlookSummary =
            SummaryText.highRain(locationName: location.displayName);
      } else if (maxProb >= 30) {
        rainOutlookSummary =
            SummaryText.moderateRain(locationName: location.displayName);
      } else {
        rainOutlookSummary =
            SummaryText.lowRain(locationName: location.displayName);
      }
    } else {
      rainOutlookSummary =
          SummaryText.noRain(locationName: location.displayName);
    }

    // Weather-only risk values.
    final expectedPrecipitationNext7dMm = dailyRain
        .map((d) => d.precipitationSumMm ?? d.rainSumMm ?? d.showersSumMm)
        .whereType<double>()
        .reduce((a, b) => a > b ? a : b);
    final maxDailyPrecipitationMm = expectedPrecipitationNext7dMm;
    final maxDailyPrecipitationProbabilityPct = dailyRain
        .map((d) => d.precipitationProbabilityMaxPct)
        .whereType<int>()
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return FloodRiskSnapshot(
      location: data.location,
      currentWeather: currentWeather,
      dailyRain: dailyRain,
      hourlyDetails: hourlyDetails,
      isStale: isStale,
      staleSince: staleSince,
      rainOutlookSummary: rainOutlookSummary,
      expectedPrecipitationNext7dMm: expectedPrecipitationNext7dMm,
      maxDailyPrecipitationMm: maxDailyPrecipitationMm,
      maxDailyPrecipitationProbabilityPct: maxDailyPrecipitationProbabilityPct,
      officialAdvisory: officialAdvisory,
      measuredWaterLevel: measuredWaterLevel,
      predictedWaterLevel: predictedWaterLevel,
      waterLevelSourceUnavailable: waterLevelSourceUnavailable,
      hasAnyRiskData: data.daily.isNotEmpty,
    );
  }

  // ── Parsers ─────────────────────────────────────────────────────────

  static CurrentWeather? _parseCurrent(Map<String, dynamic>? current) {
    if (current == null) return null;
    return CurrentWeather(
      time: current['time'] as String?,
      temperatureC: _asDouble(current['temperature_2m']),
      weatherCode: _asInt(current['weather_code']),
      windSpeedKmh: _asDouble(current['wind_speed_10m']),
      precipitationMm: _asDouble(current['precipitation']),
      relativeHumidityPct: _asDouble(current['relative_humidity_2m']),
    );
  }

  static List<WeatherDay> _parseDaily(Map<String, dynamic>? daily) {
    if (daily == null) return const [];
    final times = _stringList(daily['time']);
    final result = <WeatherDay>[];
    for (var i = 0; i < times.length; i++) {
      result.add(WeatherDay(
        time: times[i],
        temperatureMaxC: _intAt(daily['temperature_2m_max'], i),
        temperatureMinC: _intAt(daily['temperature_2m_min'], i),
        precipitationSumMm: _doubleAt(daily['precipitation_sum'], i),
        rainSumMm: _doubleAt(daily['rain_sum'], i),
        showersSumMm: _doubleAt(daily['showers_sum'], i),
        precipitationProbabilityMaxPct:
            _intAt(daily['precipitation_probability_max'], i),
        weatherCode: _intAt(daily['weather_code'], i),
        windSpeedMaxKmh: _doubleAt(daily['wind_speed_10m_max'], i)?.toString(),
      ));
    }
    return result;
  }

  static List<WeatherHour> _parseHourly(Map<String, dynamic>? hourly) {
    if (hourly == null) return const [];
    final times = _stringList(hourly['time']);
    final result = <WeatherHour>[];
    for (var i = 0; i < times.length; i++) {
      result.add(WeatherHour(
        time: times[i],
        precipitationMm: _doubleAt(hourly['precipitation'], i),
        rainMm: _doubleAt(hourly['rain'], i),
        showersMm: _doubleAt(hourly['showers'], i),
        precipitationProbabilityPct:
            _doubleAt(hourly['precipitation_probability'], i),
        weatherCode: _intAt(hourly['weather_code'], i),
        windSpeedKmh: _doubleAt(hourly['wind_speed_10m'], i),
      ));
    }
    return result;
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e?.toString() ?? '').toList();
  }

  static double? _doubleAt(dynamic raw, int index) {
    if (raw is! List || index >= raw.length) return null;
    return _asDouble(raw[index]);
  }

  static int? _intAt(dynamic raw, int index) {
    if (raw is! List || index >= raw.length) return null;
    return _asInt(raw[index]);
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
