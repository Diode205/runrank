import 'package:flutter/material.dart';

class GenderDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const GenderDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Gender',
        prefixIcon: const Icon(Icons.person),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: const [
        DropdownMenuItem(value: 'M', child: Text('Male')),
        DropdownMenuItem(value: 'F', child: Text('Female')),
      ],
      onChanged: onChanged,
      style: theme.textTheme.bodyLarge,
    );
  }
}

class DistanceDropdown extends StatelessWidget {
  final double value;
  final ValueChanged<double?> onChanged;

  const DistanceDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<double>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Race Distance (km)',
        prefixIcon: const Icon(Icons.timeline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: const [
        DropdownMenuItem(value: 5.0, child: Text('5K')),
        DropdownMenuItem(value: 8.0, child: Text('5M')),
        DropdownMenuItem(value: 10.0, child: Text('10K')),
        DropdownMenuItem(value: 16.0, child: Text('10M')),
        DropdownMenuItem(value: 21.1, child: Text('Half M')),
        DropdownMenuItem(value: 42.2, child: Text('Marathon')),
      ],
      onChanged: onChanged,
      style: theme.textTheme.bodyLarge,
    );
  }
}
