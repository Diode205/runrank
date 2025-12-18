import 'package:flutter/material.dart';

/// =============================================================
///  RELAY STAGE SELECTOR + PACE INPUT
/// =============================================================
class RelayStageSelector extends StatefulWidget {
  final int? initialStage;
  final String? initialPace;
  final void Function(int stage, String pace) onSubmit;

  const RelayStageSelector({
    super.key,
    required this.onSubmit,
    this.initialStage,
    this.initialPace,
  });

  @override
  State<RelayStageSelector> createState() => _RelayStageSelectorState();
}

class _RelayStageSelectorState extends State<RelayStageSelector> {
  int? selectedStage;
  TextEditingController paceController = TextEditingController();

  final relayStages = const [
    {"n": 1, "name": "Kings Lynn → Hunstanton", "dist": "16.3"},
    {"n": 2, "name": "Hunstanton → Burnham Overy", "dist": "13.6"},
    {"n": 3, "name": "Burnham Overy → Wells", "dist": "11.1"},
    {"n": 4, "name": "Wells → Cley", "dist": "14.0"},
    {"n": 5, "name": "Cley → Cromer", "dist": "10.8"},
    {"n": 6, "name": "Cromer → Mundesley", "dist": "7.9"},
    {"n": 7, "name": "Mundesley → Lessingham", "dist": "9.9"},
    {"n": 8, "name": "Lessingham → Horsey", "dist": "7.5"},
    {"n": 9, "name": "Horsey → Martham", "dist": "16.7"},
    {"n": 10, "name": "Martham → Belton", "dist": "12.5"},
    {"n": 11, "name": "Belton → Earsham", "dist": "18.1"},
    {"n": 12, "name": "Earsham → Scole", "dist": "13.3"},
    {"n": 13, "name": "Scole → Thetford", "dist": "19.7"},
    {"n": 14, "name": "Thetford → Feltwell", "dist": "14.1"},
    {"n": 15, "name": "Feltwell → Wissington", "dist": "7.4"},
    {"n": 16, "name": "Wissington → Downham Market", "dist": "10.6"},
    {"n": 17, "name": "Downham Market → Kings Lynn", "dist": "11.5"},
  ];

  @override
  void initState() {
    super.initState();
    selectedStage = widget.initialStage;
    paceController.text = widget.initialPace ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Relay Stage & Predicted Pace"),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: selectedStage,
              decoration: const InputDecoration(labelText: "Choose Stage"),
              items: relayStages.map((s) {
                return DropdownMenuItem(
                  value: s["n"] as int,
                  child: Text(
                    "Stage ${s['n']} — ${s['name']} (${s['dist']} mi)",
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => selectedStage = v),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: paceController,
              decoration: const InputDecoration(
                labelText: "Predicted Pace (mm:ss per mile)",
                hintText: "e.g. 7:45",
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: selectedStage == null
              ? null
              : () {
                  widget.onSubmit(selectedStage!, paceController.text.trim());
                  Navigator.pop(context);
                },
          child: const Text("Save"),
        ),
      ],
    );
  }
}

/// =============================================================
///  HANDICAP PACE INPUT
/// =============================================================
class HandicapPaceInput extends StatefulWidget {
  final String? initialPace;
  final void Function(String pace) onSubmit;

  const HandicapPaceInput({
    super.key,
    required this.onSubmit,
    this.initialPace,
  });

  @override
  State<HandicapPaceInput> createState() => _HandicapPaceInputState();
}

class _HandicapPaceInputState extends State<HandicapPaceInput> {
  late TextEditingController paceController;

  @override
  void initState() {
    super.initState();
    paceController = TextEditingController(text: widget.initialPace ?? "");
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Predicted Pace"),
      content: TextField(
        controller: paceController,
        decoration: const InputDecoration(
          labelText: "Predicted Pace (mm:ss per mile)",
          hintText: "Example: 8:30",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSubmit(paceController.text.trim());
            Navigator.pop(context);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}

/// =============================================================
///  EXPANDABLE PARTICIPANT LISTS
/// =============================================================
class ParticipantsExpandableList extends StatelessWidget {
  final List<dynamic> runners;
  final List<dynamic> volunteers;
  final List<dynamic> unavailable;

  const ParticipantsExpandableList({
    super.key,
    required this.runners,
    required this.volunteers,
    required this.unavailable,
  });

  Widget _buildTile(String title, String icon, List<dynamic> items) {
    return ExpansionTile(
      leading: Text(icon, style: const TextStyle(fontSize: 22)),
      title: Text("$title (${items.length})"),
      children: items.isEmpty
          ? [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text("No participants"),
              ),
            ]
          : items.map((e) {
              return ListTile(title: Text(e['user_name'] ?? "Unknown User"));
            }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTile("Running", "🏃", runners),
        _buildTile("Volunteers", "🤝", volunteers),
        _buildTile("Unavailable", "❌", unavailable),
      ],
    );
  }
}
