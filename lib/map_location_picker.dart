import 'package:flutter/material.dart';

class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({super.key});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  double lat = 52.9; // Default Norfolk
  double lng = 1.3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Location")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 80, color: Colors.blueGrey),

            const SizedBox(height: 20),
            Text("Latitude: $lat"),
            Text("Longitude: $lng"),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {"lat": lat, "lng": lng});
              },
              child: const Text("Use This Location"),
            ),
          ],
        ),
      ),
    );
  }
}
