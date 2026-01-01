import 'package:flutter/material.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/services/weather_service.dart';
import 'package:runrank/config/maps_config.dart';

/// Small card showing a static map preview and on-the-day weather
/// for an event venue. Used across simple, race, and relay details.
class EventVenuePreview extends StatefulWidget {
  final ClubEvent event;
  final VoidCallback onOpenMaps;

  const EventVenuePreview({
    super.key,
    required this.event,
    required this.onOpenMaps,
  });

  @override
  State<EventVenuePreview> createState() => _EventVenuePreviewState();
}

class _EventVenuePreviewState extends State<EventVenuePreview> {
  WeatherAtTime? _weather;
  bool _weatherLoading = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final eventTime = widget.event.dateTime;
    final diff = eventTime.difference(now).inDays;
    // Only fetch/show weather within 7 days of the event.
    if (diff.abs() <= 7) {
      _loadWeather();
    }
  }

  Future<void> _loadWeather() async {
    final lat = widget.event.latitude;
    final lng = widget.event.longitude;
    if (lat == null || lng == null) return;

    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });

    try {
      final result = await WeatherService.fetchWeather(
        latitude: lat,
        longitude: lng,
        when: widget.event.dateTime,
      );

      if (!mounted) return;
      setState(() {
        _weather = result;
        _weatherLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherError = "Weather unavailable right now";
        _weatherLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.event.latitude;
    final lng = widget.event.longitude;
    if (lat == null || lng == null) {
      return const SizedBox.shrink();
    }

    final mapUrl = _mapPreviewUrl(lat, lng);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.venue.isNotEmpty ? widget.event.venue : "Venue",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.event.venueAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.event.venueAddress,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 21 / 9,
              child: GestureDetector(
                onTap: widget.onOpenMaps,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        mapUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.black12,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  color: Colors.white60,
                                  size: 28,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Map preview not available",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.map_outlined,
                              size: 14,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Tap for Maps",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildWeatherStrip(),
        ],
      ),
    );
  }

  Widget _buildWeatherStrip() {
    final now = DateTime.now();
    final eventTime = widget.event.dateTime;
    final diff = eventTime.difference(now).inDays;
    if (diff > 7) {
      // Hide weather completely until we are within a week of the event.
      return const SizedBox.shrink();
    }

    if (_weatherLoading) {
      return Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text("Loading weather...", style: TextStyle(color: Colors.white70)),
        ],
      );
    }

    if (_weather != null) {
      final w = _weather!;
      return Row(
        children: [
          Icon(_weatherIcon(w.code), color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            "${w.tempC.round()}°C • ${w.windMph.round()} mph",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              w.description,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      );
    }

    if (_weatherError != null) {
      return Text(
        _weatherError!,
        style: const TextStyle(color: Colors.white70),
      );
    }

    return const Text(
      "Weather not available",
      style: TextStyle(color: Colors.white70),
    );
  }

  IconData _weatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2) return Icons.wb_cloudy_rounded;
    if (code == 3 || code == 45 || code == 48) return Icons.cloud;
    if (code >= 51 && code <= 67) return Icons.grain_rounded;
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return Icons.ac_unit_rounded;
    }
    if ((code >= 80 && code <= 82) || (code >= 61 && code <= 65)) {
      return Icons.grain_rounded;
    }
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue;
  }

  String _mapPreviewUrl(double lat, double lng) {
    if (googleStaticMapsApiKey.isNotEmpty) {
      final center = '$lat,$lng';
      final marker = 'color:red|$lat,$lng';
      return 'https://maps.googleapis.com/maps/api/staticmap'
          '?center=$center'
          '&zoom=15'
          '&size=600x300'
          '&maptype=roadmap'
          '&markers=$marker'
          '&key=$googleStaticMapsApiKey';
    }

    // Fallback to OpenStreetMap static maps when no Google key is set.
    return 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$lat,$lng&zoom=14&size=600x300&markers=$lat,$lng,red-pushpin';
  }
}
