import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lightweight wrapper around the open-meteo API to fetch forecast data for a
/// specific time without requiring an API key.
class WeatherAtTime {
  final double tempC;
  final double windMph;
  final int code;
  final String description;

  const WeatherAtTime({
    required this.tempC,
    required this.windMph,
    required this.code,
    required this.description,
  });
}

class WeatherService {
  static Future<WeatherAtTime?> fetchWeather({
    required double latitude,
    required double longitude,
    required DateTime when,
  }) async {
    final dateStr =
        "${when.year.toString().padLeft(4, '0')}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}";
    final uri = Uri.parse(
      "https://api.open-meteo.com/v1/forecast"
      "?latitude=$latitude"
      "&longitude=$longitude"
      "&hourly=temperature_2m,weathercode,windspeed_10m"
      "&timezone=auto"
      "&start_date=$dateStr"
      "&end_date=$dateStr",
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return null;

    final times = (hourly['time'] as List<dynamic>?)?.cast<String>();
    final temps = (hourly['temperature_2m'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble())
        .toList();
    final codes = (hourly['weathercode'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    final winds = (hourly['windspeed_10m'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble())
        .toList();

    if (times == null || temps == null || codes == null || winds == null) {
      return null;
    }

    final target = DateTime(when.year, when.month, when.day, when.hour);
    var bestIndex = 0;
    var bestDiff = const Duration(days: 365);

    for (var i = 0; i < times.length; i++) {
      final t = DateTime.tryParse(times[i]);
      if (t == null) continue;
      final diff = t.difference(target).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }

    final tempC = temps[bestIndex];
    final windMph = _kmhToMph(winds[bestIndex]);
    final code = codes[bestIndex];

    return WeatherAtTime(
      tempC: tempC,
      windMph: windMph,
      code: code,
      description: _describe(code),
    );
  }

  static double _kmhToMph(double kmh) => kmh * 0.621371;

  static String _describe(int code) {
    if (code == 0) return "Clear";
    if (code == 1 || code == 2) return "Partly cloudy";
    if (code == 3) return "Cloudy";
    if (code == 45 || code == 48) return "Fog";
    if (code == 51 || code == 53 || code == 55) return "Drizzle";
    if (code == 56 || code == 57) return "Freezing drizzle";
    if (code == 61 || code == 63 || code == 65) return "Rain";
    if (code == 66 || code == 67) return "Freezing rain";
    if (code == 71 || code == 73 || code == 75) return "Snow";
    if (code == 77) return "Snow grains";
    if (code == 80 || code == 81 || code == 82) return "Rain showers";
    if (code == 85 || code == 86) return "Snow showers";
    if (code == 95) return "Thunderstorm";
    if (code == 96 || code == 99) return "Thunderstorm w/ hail";
    return "Weather";
  }
}
