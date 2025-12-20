import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';

class AdminCreateEventPage extends StatefulWidget {
  final String userRole;

  const AdminCreateEventPage({super.key, required this.userRole});

  @override
  State<AdminCreateEventPage> createState() => _AdminCreateEventPageState();
}

class _AdminCreateEventPageState extends State<AdminCreateEventPage> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  late List<String> adminTypes;
  late List<String> socialTypes;

  @override
  void initState() {
    super.initState();

    adminTypes = [
      "Training 1",
      "Training 2",
      "Race",
      "Handicap Series",
      "Relay",
      "Special Event",
    ];

    socialTypes = ["Social Run", "Meet & Drink", "Swim or Cycle", "Others"];

    selectedCategory = widget.userRole == "admin" ? "admin" : "social";
    selectedEventType = selectedCategory == "admin"
        ? adminTypes.first
        : socialTypes.first;
  }

  String selectedEventType = "";
  String selectedCategory = "";

  // Controllers
  final hostCtrl = TextEditingController();
  final venueCtrl = TextEditingController();
  final venueAddressCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  // Date fields
  DateTime? selectedDate;
  DateTime? marshalCallDate;
  TimeOfDay? selectedTime;

  // Handicap dropdown
  final handicapDistances = const ["5K", "5M", "10K", "10M", "7M", "Beach Run"];
  String? selectedHandicapDistance;

  // Relay Team
  String selectedRelayTeam = "A";

  // RACE LIST
  final raceNames = const ["Holt 10K", "Worstead 5M", "Chase The Train"];
  String? selectedRace;

  @override
  void dispose() {
    hostCtrl.dispose();
    venueCtrl.dispose();
    venueAddressCtrl.dispose();
    descriptionCtrl.dispose();
    super.dispose();
  }

  // Date pickers
  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> pickMarshalDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: marshalCallDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => marshalCallDate = picked);
  }

  String buildTitle() {
    switch (selectedEventType) {
      case "Training 1":
        return "Training 1";
      case "Training 2":
        return "Training 2";
      case "Race":
        return "Race: $selectedRace";
      case "Handicap Series":
        return "Handicap (${selectedHandicapDistance ?? ""})";
      case "Relay":
        return "RNR Relay – Team $selectedRelayTeam";
      case "Special Event":
        return "Special Event";
      default:
        return selectedEventType;
    }
  }

  Future<void> saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a date")));
      return;
    }

    if (selectedTime == null && selectedEventType != "Relay") {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a time")));
      return;
    }

    final timeString = selectedEventType == "Relay"
        ? "00:00"
        : "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}";

    final map = {
      "event_type": selectedEventType.toLowerCase().replaceAll(" ", "_"),
      "training_number": selectedEventType == "Training 1"
          ? 1
          : selectedEventType == "Training 2"
          ? 2
          : null,
      "race_name": selectedEventType == "Race" ? selectedRace : null,
      "handicap_distance": selectedEventType == "Handicap Series"
          ? selectedHandicapDistance
          : null,
      "relay_team": selectedEventType == "Relay" ? selectedRelayTeam : null,
      "title": buildTitle(),
      "date": selectedDate!.toIso8601String().split("T").first,
      "time": timeString,
      "host_or_director": hostCtrl.text.trim(),
      "venue": venueCtrl.text.trim(),
      "venue_address": venueAddressCtrl.text.trim(),
      "description": descriptionCtrl.text.trim(),
      "marshal_call_date":
          (selectedEventType == "Race" ||
              selectedEventType == "Handicap Series")
          ? marshalCallDate?.toIso8601String().split("T").first
          : null,
      "expected_time_required":
          selectedEventType == "Handicap Series" || selectedEventType == "Relay"
          ? true
          : false,
      "created_by": supabase.auth.currentUser?.id,
    };

    try {
      final result = await supabase.from("club_events").insert(map).select();

      if (!mounted) return;

      // Send notification to all users about new event
      if (result.isNotEmpty) {
        final eventId = result.first['id']?.toString();
        if (eventId != null) {
          final eventTitle = buildTitle();
          await NotificationService.notifyAllUsers(
            title: 'New Event Created',
            body: '$eventTitle has been added to the calendar',
            eventId: eventId,
            targetScreen: 'calendar',
          );
        }
      }

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event created successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  Widget _section(String title, Widget child) {
    return Card(
      elevation: 1,
      color: const Color.fromARGB(226, 101, 105, 101),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Event")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.userRole == "admin"
                          ? () => setState(() {
                              selectedCategory = "admin";
                              selectedEventType = adminTypes.first;
                            })
                          : null,
                      child: const Text("Admin Events"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() {
                        selectedCategory = "social";
                        selectedEventType = socialTypes.first;
                      }),
                      child: const Text("Social Events"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// EVENT TYPE
              _section(
                "Event Type",
                DropdownButtonFormField<String>(
                  value: selectedEventType,
                  items: selectedCategory == "admin"
                      ? adminTypes
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList()
                      : socialTypes
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                  onChanged: (v) => setState(() => selectedEventType = v!),
                ),
              ),

              const SizedBox(height: 12),

              // RACE UI
              if (selectedEventType == "Race")
                _section(
                  "Race Name",
                  DropdownButtonFormField<String>(
                    value: selectedRace,
                    items: raceNames
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedRace = v),
                    decoration: const InputDecoration(labelText: "Select Race"),
                  ),
                ),

              // HANDICAP UI
              if (selectedEventType == "Handicap Series")
                _section(
                  "Handicap Event",
                  DropdownButtonFormField<String>(
                    value: selectedHandicapDistance,
                    items: handicapDistances
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => selectedHandicapDistance = v),
                  ),
                ),

              // RELAY UI
              if (selectedEventType == "Relay")
                _section(
                  "Relay Team",
                  DropdownButtonFormField<String>(
                    value: selectedRelayTeam,
                    items: const [
                      DropdownMenuItem(value: "A", child: Text("Team A")),
                      DropdownMenuItem(value: "B", child: Text("Team B")),
                    ],
                    onChanged: (v) => setState(() => selectedRelayTeam = v!),
                  ),
                ),

              const SizedBox(height: 12),

              // HOST / VENUE / DESCRIPTION
              _section(
                "Event Details",
                Column(
                  children: [
                    TextFormField(
                      controller: hostCtrl,
                      decoration: const InputDecoration(labelText: "Host"),
                      validator: (v) => v!.trim().isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: venueCtrl,
                      decoration: const InputDecoration(labelText: "Venue"),
                      validator: (v) => v!.trim().isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: venueAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: "Venue Address",
                      ),
                    ),
                    TextFormField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Description",
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              /// DATE & TIME
              Card(
                elevation: 1,
                color: const Color.fromARGB(255, 74, 75, 76),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Date & Time",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.yellow[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: pickDate,
                              child: Text(
                                selectedDate == null
                                    ? "Pick Date"
                                    : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                              ),
                            ),
                          ),
                          if (selectedEventType != "Relay") ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime:
                                        selectedTime ?? TimeOfDay.now(),
                                  );
                                  if (t != null)
                                    setState(() => selectedTime = t);
                                },
                                child: Text(
                                  selectedTime == null
                                      ? "Pick Time"
                                      : "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}",
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // MARSHAL CALL DATE
              if (selectedEventType == "Race" ||
                  selectedEventType == "Handicap Series")
                _section(
                  "Marshal Call Date",
                  OutlinedButton(
                    onPressed: pickMarshalDate,
                    child: Text(
                      marshalCallDate == null
                          ? "Pick Marshal Call Date"
                          : "${marshalCallDate!.day}/${marshalCallDate!.month}/${marshalCallDate!.year}",
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: saveEvent,
                  icon: const Icon(Icons.save),
                  label: const Text("Save Event"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
