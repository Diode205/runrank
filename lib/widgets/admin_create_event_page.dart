import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';

class AdminCreateEventPage extends StatefulWidget {
  final String userRole;
  final String? initialEventType;
  final String? initialHandicapDistance;
  final DateTime? initialDate;
  final String? initialVenue;
  final String? initialRaceName;
  final String? initialVenueAddress;
  final String? initialRelayFormat;

  const AdminCreateEventPage({
    super.key,
    required this.userRole,
    this.initialEventType,
    this.initialHandicapDistance,
    this.initialDate,
    this.initialVenue,
    this.initialRaceName,
    this.initialVenueAddress,
    this.initialRelayFormat,
  });

  @override
  State<AdminCreateEventPage> createState() => _AdminCreateEventPageState();
}

class _AdminCreateEventPageState extends State<AdminCreateEventPage> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  late List<String> adminTypes;
  late List<String> socialTypes;

  // Host selection
  List<Map<String, dynamic>> _hosts = [];
  String? _selectedHostId;

  @override
  void initState() {
    super.initState();

    adminTypes = [
      "Training 1",
      "Training 2",
      "Race",
      "Cross Country",
      "Handicap Series",
      "Relay",
      "Special Event",
    ];

    socialTypes = ["Social Run", "Meet & Drink", "Swim or Cycle", "Others"];

    selectedCategory = widget.userRole == "admin" ? "admin" : "social";
    selectedEventType = selectedCategory == "admin"
        ? adminTypes.first
        : socialTypes.first;

    // Apply any provided initial values for prefilled navigation
    if (widget.initialEventType != null) {
      selectedCategory = "admin"; // only admin creates events here
      selectedEventType = widget.initialEventType!;
    }
    if (widget.initialHandicapDistance != null) {
      selectedHandicapDistance = widget.initialHandicapDistance;
    }
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate;
    }
    if (widget.initialVenue != null) {
      venueCtrl.text = widget.initialVenue!;
    }
    if (widget.initialRaceName != null) {
      crossCountryRaceNameCtrl.text = widget.initialRaceName!;
    }
    if (widget.initialVenueAddress != null) {
      venueAddressCtrl.text = widget.initialVenueAddress!;
    }
    if (widget.initialRelayFormat != null) {
      _selectedRelayFormat = widget.initialRelayFormat!;
    }

    // Default time for all events (2:30 pm) unless explicitly changed
    selectedTime ??= const TimeOfDay(hour: 14, minute: 30);

    _loadHosts();
  }

  String selectedEventType = "";
  String selectedCategory = "";
  String _selectedRelayFormat = "RNR"; // "RNR" or "Ekiden"

  // Controllers
  final hostCtrl = TextEditingController();
  final venueCtrl = TextEditingController();
  final venueAddressCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final latitudeCtrl = TextEditingController();
  final longitudeCtrl = TextEditingController();
  final crossCountryRaceNameCtrl = TextEditingController();

  // Date fields
  DateTime? selectedDate;
  DateTime? marshalCallDate;
  TimeOfDay? selectedTime;

  // Handicap dropdown
  final handicapDistances = const ["5K", "5M", "10K", "10M", "7M", "Beach Run"];
  String? selectedHandicapDistance;

  // Relay team name (free text, e.g. "RNR Team X")
  final relayTeamCtrl = TextEditingController();

  // RACE LIST
  final raceNames = const ["Holt 10K", "Worstead 5M", "Chase The Train"];
  String? selectedRace;

  Future<void> _loadHosts() async {
    try {
      final rows = await supabase
          .from('user_profiles')
          .select('id, full_name, is_admin')
          .order('full_name');

      final currentUserId = supabase.auth.currentUser?.id;

      setState(() {
        _hosts = rows
            .map<Map<String, dynamic>>(
              (r) => {
                'id': r['id'] as String,
                'full_name': (r['full_name'] as String?) ?? 'Member',
                'is_admin': (r['is_admin'] as bool?) ?? false,
              },
            )
            .toList();

        // Default host to current user if present, otherwise first in list.
        Map<String, dynamic>? initial;
        if (currentUserId != null) {
          initial = _hosts.firstWhere(
            (h) => h['id'] == currentUserId,
            orElse: () => _hosts.isNotEmpty
                ? _hosts.first
                : <String, dynamic>{'id': null, 'full_name': ''},
          );
        } else if (_hosts.isNotEmpty) {
          initial = _hosts.first;
        }

        if (initial != null && initial['id'] != null) {
          _selectedHostId = initial['id'] as String;
          hostCtrl.text = initial['full_name'] as String;
        }
      });
    } catch (e) {
      debugPrint('Error loading hosts: $e');
    }
  }

  @override
  void dispose() {
    hostCtrl.dispose();
    venueCtrl.dispose();
    venueAddressCtrl.dispose();
    descriptionCtrl.dispose();
    latitudeCtrl.dispose();
    longitudeCtrl.dispose();
    crossCountryRaceNameCtrl.dispose();
    relayTeamCtrl.dispose();
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
      case "Cross Country":
        final name = crossCountryRaceNameCtrl.text.trim();
        return name.isEmpty ? "Cross Country" : "Cross Country: $name";
      case "Handicap Series":
        return "Handicap (${selectedHandicapDistance ?? ""})";
      case "Relay":
        return "Relay";
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

    double? latitude;
    double? longitude;
    if (latitudeCtrl.text.trim().isNotEmpty) {
      latitude = double.tryParse(latitudeCtrl.text.trim());
      if (latitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Latitude must be a number (e.g. 52.9501)"),
          ),
        );
        return;
      }
    }
    if (longitudeCtrl.text.trim().isNotEmpty) {
      longitude = double.tryParse(longitudeCtrl.text.trim());
      if (longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Longitude must be a number (e.g. 1.3012)"),
          ),
        );
        return;
      }
    }

    // Build relay_team value depending on relay format
    String? relayTeamValue;
    if (selectedEventType == "Relay") {
      final teamName = relayTeamCtrl.text.trim();
      if (_selectedRelayFormat == "Ekiden") {
        relayTeamValue = teamName.isEmpty ? "Ekiden" : "Ekiden: $teamName";
      } else {
        relayTeamValue = teamName.isEmpty ? null : teamName;
      }
    }

    final map = {
      "event_type": selectedEventType.toLowerCase().replaceAll(" ", "_"),
      "training_number": selectedEventType == "Training 1"
          ? 1
          : selectedEventType == "Training 2"
          ? 2
          : null,
      "race_name": selectedEventType == "Race"
          ? selectedRace
          : selectedEventType == "Cross Country"
          ? crossCountryRaceNameCtrl.text.trim()
          : null,
      "handicap_distance": selectedEventType == "Handicap Series"
          ? selectedHandicapDistance
          : null,
      "relay_team": relayTeamValue,
      "title": buildTitle(),
      "date": selectedDate!.toIso8601String().split("T").first,
      "time": timeString,
      "host_or_director": hostCtrl.text.trim(),
      "host_user_id": _selectedHostId,
      "venue": venueCtrl.text.trim(),
      "venue_address": venueAddressCtrl.text.trim(),
      "description": descriptionCtrl.text.trim(),
      "latitude": latitude,
      "longitude": longitude,
      "marshal_call_date":
          (selectedEventType == "Race" ||
              selectedEventType == "Cross Country" ||
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

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      // Send notification to all users about new event
      if (result.isNotEmpty) {
        final eventId = result.first['id']?.toString();
        if (eventId != null) {
          final eventTitle = buildTitle();

          await NotificationService.notifyAllUsers(
            title: 'New Event Created',
            body: '$eventTitle has been added to the calendar',
            eventId: eventId,
          );
        }
      }

      if (mounted) {
        navigator.pop(true);
        messenger.showSnackBar(
          const SnackBar(content: Text("Event created successfully!")),
        );
      }
    } catch (e) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  Widget _section(String title, Widget child) {
    return Card(
      elevation: 1,
      color: const Color(0xFF0F111A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFF5C542), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF4A90E2),
                          width: 1,
                        ),
                        foregroundColor: const Color(0xFFF5C542),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF4A90E2),
                          width: 1,
                        ),
                        foregroundColor: const Color(0xFFF5C542),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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
                  initialValue: selectedEventType,
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
                    initialValue: selectedRace,
                    items: raceNames
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedRace = v),
                    decoration: const InputDecoration(labelText: "Select Race"),
                  ),
                ),

              // CROSS COUNTRY UI
              if (selectedEventType == "Cross Country")
                _section(
                  "Race Name",
                  TextFormField(
                    controller: crossCountryRaceNameCtrl,
                    decoration: const InputDecoration(labelText: "Race Name"),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "Required" : null,
                  ),
                ),

              // HANDICAP UI
              if (selectedEventType == "Handicap Series")
                _section(
                  "Handicap Event",
                  DropdownButtonFormField<String>(
                    initialValue: selectedHandicapDistance,
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
                  "Relay",
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedRelayFormat,
                        decoration: const InputDecoration(
                          labelText: "Relay type",
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: "RNR",
                            child: Text("RNR Relay"),
                          ),
                          DropdownMenuItem(
                            value: "Ekiden",
                            child: Text("Ekiden Relay"),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedRelayFormat = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: relayTeamCtrl,
                        decoration: const InputDecoration(
                          labelText: "Team name (optional)",
                          hintText: "Name your team (e.g. RNR Team X)",
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // HOST / VENUE / DESCRIPTION
              _section(
                "Event Details",
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedHostId,
                      decoration: const InputDecoration(
                        labelText: "Host / Director",
                      ),
                      items: _hosts
                          .where(
                            (h) => selectedCategory == "admin"
                                ? (h['is_admin'] as bool? ?? false)
                                : true,
                          )
                          .map(
                            (h) => DropdownMenuItem<String>(
                              value: h['id'] as String,
                              child: Text(
                                (h['full_name'] as String?) ?? 'Member',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedHostId = value;
                          final match = _hosts.firstWhere(
                            (h) => h['id'] == value,
                            orElse: () => <String, dynamic>{'full_name': ''},
                          );
                          hostCtrl.text = (match['full_name'] as String?) ?? '';
                        });
                      },
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    if (selectedCategory == "admin")
                      const Padding(
                        padding: EdgeInsets.only(top: 6.0, bottom: 4.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "For Admin Events, only admin users can be selected as hosts.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
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
                      controller: latitudeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Latitude (optional)",
                        hintText: "52.9501",
                      ),
                    ),
                    TextFormField(
                      controller: longitudeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Longitude (optional)",
                        hintText: "1.3012",
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Tip: In Google Maps, right‑click the venue and copy the first number (lat) and second number (lon).",
                      style: TextStyle(fontSize: 12, color: Colors.white70),
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
                color: const Color(0xFF0F111A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF4A90E2), width: 1),
                ),
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
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF4A90E2),
                                  width: 1,
                                ),
                                foregroundColor: Colors.white,
                              ),
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
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF4A90E2),
                                    width: 1,
                                  ),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime:
                                        selectedTime ?? TimeOfDay.now(),
                                  );
                                  if (t != null) {
                                    setState(() => selectedTime = t);
                                  }
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
                  selectedEventType == "Cross Country" ||
                  selectedEventType == "Handicap Series")
                _section(
                  "Marshal Call Date",
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: pickMarshalDate,
                      child: Text(
                        marshalCallDate == null
                            ? "Tap To Set"
                            : "${marshalCallDate!.day}/${marshalCallDate!.month}/${marshalCallDate!.year}",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF5C542), width: 1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
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
