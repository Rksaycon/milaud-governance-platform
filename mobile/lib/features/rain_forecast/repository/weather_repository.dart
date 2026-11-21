/// Re-exports the canonical [WeatherRepository] from the services layer.
///
/// Kept as a re-export so existing imports
/// (`package:may_laud/features/rain_forecast/repository/weather_repository.dart`)
/// continue to resolve without changes.
library;

export '../../../services/weather_repository.dart';
