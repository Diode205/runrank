import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';

class _SavedVenuePreset {
  final String venue;
  final String address;
  final String latitude;
  final String longitude;

  const _SavedVenuePreset({
    required this.venue,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  String get id => '${venue.trim()}|${address.trim()}';

  String get label {
    return venue.trim();
  }

  Map<String, dynamic> toJson() => {
    'venue': venue,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory _SavedVenuePreset.fromJson(Map<String, dynamic> json) {
    return _SavedVenuePreset(
      venue: (json['venue'] as String? ?? '').trim(),
      address: (json['address'] as String? ?? '').trim(),
      latitude: (json['latitude'] as String? ?? '').trim(),
      longitude: (json['longitude'] as String? ?? '').trim(),
    );
  }
}

class AdminCreateEventPage extends StatefulWidget {
  final String userRole;
  final String? initialEventType;
  final String? initialHandicapDistance;
  final DateTime? initialDate;
  final String? initialVenue;
  final String? initialRaceName;
  final String? initialVenueAddress;
  final String? initialRelayFormat;
  final double? initialLatitude;
  final double? initialLongitude;

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
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<AdminCreateEventPage> createState() => _AdminCreateEventPageState();
}

class _AdminCreateEventPageState extends State<AdminCreateEventPage> {
  static const Map<String, _SavedVenuePreset> _raceVenuePresets = {
    'Dinosaur Dash': _SavedVenuePreset(
      venue: 'Roarr Adventure Park',
      address: 'Lenwade Norwich',
      latitude: '52.71297101786584',
      longitude: '1.1201313893317326',
    ),
    'Wroxham 5K': _SavedVenuePreset(
      venue: 'Broadland High Ormiston Academy',
      address: 'Wroxham',
      latitude: '52.71665374668599',
      longitude: '1.4141447659842001',
    ),
  };

  static const Map<String, _SavedVenuePreset> _crossCountryVenuePresets = {
    'Broadland Country Park Race 1': _SavedVenuePreset(
      venue: 'Broadland Country Park',
      address: 'Horsford Norwich',
      latitude: '52.7108107164322',
      longitude: '1.2260404278394894',
    ),
    'Broadland Country Park Race 2': _SavedVenuePreset(
      venue: 'Broadland Country Park',
      address: 'Horsford Norwich',
      latitude: '52.7108107164322',
      longitude: '1.2260404278394894',
    ),
    'Broadland Country Park Race 3': _SavedVenuePreset(
      venue: 'Broadland Country Park',
      address: 'Horsford Norwich',
      latitude: '52.7108107164322',
      longitude: '1.2260404278394894',
    ),
  };

  static const Map<String, _SavedVenuePreset> _relayVenuePresets = {
    'RNR': _SavedVenuePreset(
      venue: 'Lynnsport',
      address: 'Kings Lynn',
      latitude: '52.7625527580909',
      longitude: '0.41744744668855344',
    ),
    'Ekiden': _SavedVenuePreset(
      venue: 'Ipswich High School',
      address: 'Woolverstone',
      latitude: '52.003048545066015',
      longitude: '1.1952880774216965',
    ),
    'AlexMoore': _SavedVenuePreset(
      venue: 'Norfolk Showground',
      address: 'Norwich',
      latitude: '52.64978545095906',
      longitude: '1.1767761647985628',
    ),
    'NorwichTriathlon': _SavedVenuePreset(
      venue: 'Whitlingham Country Park',
      address: 'Norwich',
      latitude: '52.621704228248134',
      longitude: '1.3391771752640746',
    ),
    'Sandringham24': _SavedVenuePreset(
      venue: 'Sandringham Estate',
      address: 'Norfolk',
      latitude: '52.82982259449807',
      longitude: '0.5124635792869614',
    ),
  };

  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  late List<String> adminTypes;
  late List<String> socialTypes;
  late List<String> raceNames;

  String? _clubName;
  bool get _isNRRClub =>
      _clubName != null &&
      _clubName!.toLowerCase().contains('norwich road runners');

  // Host selection
  List<Map<String, dynamic>> _hosts = [];
  String? _selectedHostId;
  List<_SavedVenuePreset> _savedVenuePresets = [];
  String? _selectedSavedVenueId;

  @override
  void initState() {
    super.initState();

    adminTypes = [
      "Training",
      "Race",
      "Cross Country",
      "Handicap Series",
      "Relay",
      "Special Event",
    ];

    socialTypes = ["Social Run", "Meet & Drink", "Swim or Cycle", "Others"];

    // Default NNBR race list; this may be overridden once we know the club.
    raceNames = ["Holt 10K", "Worstead 5M", "Chase The Train"];

    selectedCategory = widget.userRole == "admin" ? "admin" : "social";
    selectedEventType = selectedCategory == "admin"
        ? adminTypes.first
        : socialTypes.first;

    // Apply any provided initial values for prefilled navigation
    if (widget.initialEventType != null) {
      selectedCategory = "admin"; // only admin creates events here
      final initType = widget.initialEventType!;
      if (initType == "Training 1" || initType == "Training 2") {
        // Legacy callers may still pass the old labels; normalise
        // them into the new unified Training type.
        selectedEventType = "Training";
      } else {
        selectedEventType = initType;
      }
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
    if (widget.initialLatitude != null) {
      latitudeCtrl.text = widget.initialLatitude!.toString();
    }
    if (widget.initialLongitude != null) {
      longitudeCtrl.text = widget.initialLongitude!.toString();
    }

    // Default time for all events (2:30 pm) unless explicitly changed
    selectedTime ??= const TimeOfDay(hour: 14, minute: 30);

    _loadHosts();
  }

  String selectedEventType = "";
  String selectedCategory = "";
  String _selectedRelayFormat = "RNR"; // "RNR" or "Ekiden"

  // Special Event subtype (e.g. AGM, Club Nights, Awards Night)
  static const List<String> _specialEventTypes = <String>[
    'AGM',
    'Club Nights',
    'Awards Night',
  ];
  String? _selectedSpecialEventType;

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

  // RACE LIST (defaults for NNBR; overridden for NRR once club is known)
  String? selectedRace;

  // NRR-specific Cross Country series races
  static const List<String> _nrrCrossCountryRaces = <String>[
    'Broadland Country Park Race 1',
    'Broadland Country Park Race 2',
    'Broadland Country Park Race 3',
  ];

  Future<void> _loadHosts() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;

      // Resolve the current user's club so that the Host/Director
      // dropdown only shows members (and admins) from the same club.
      String? clubName;
      if (currentUserId != null) {
        try {
          final profile = await supabase
              .from('user_profiles')
              .select('club')
              .eq('id', currentUserId)
              .maybeSingle();

          final raw = (profile?['club'] as String?)?.trim();
          clubName = (raw != null && raw.isNotEmpty) ? raw : null;
        } catch (e) {
          debugPrint(
            'AdminCreateEventPage: error loading current user club: $e',
          );
        }
      }

      var query = supabase
          .from('user_profiles')
          .select('id, full_name, is_admin');

      if (clubName != null) {
        query = query.eq('club', clubName);
      }

      final rows = await query.order('full_name');

      setState(() {
        _clubName = clubName;

        // Adjust admin event types and race list based on club.
        if (_isNRRClub) {
          // For NRR: keep all admin event types except Handicap Series.
          adminTypes = [
            "Training",
            "Race",
            "Cross Country",
            "Relay",
            "Special Event",
          ];

          // NRR signature races for the Race dropdown.
          raceNames = ["Royal Norwich HM", "Dinosaur Dash", "Wroxham 5K"];
        } else {
          // Default (NNBR and other clubs).
          adminTypes = [
            "Training",
            "Race",
            "Cross Country",
            "Handicap Series",
            "Relay",
            "Special Event",
          ];

          raceNames = ["Holt 10K", "Worstead 5M", "Chase The Train"];
        }

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

      await _loadSavedVenuePresets();
      _applyFixedVenuePresetForCurrentSelection();
    } catch (e) {
      debugPrint('Error loading hosts: $e');
    }
  }

  String _savedVenuesPrefsKey() {
    final rawClub = (_clubName ?? 'default_club').trim().toLowerCase();
    final safeClub = rawClub.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'admin_saved_venues_$safeClub';
  }

  Future<void> _loadSavedVenuePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_savedVenuesPrefsKey()) ?? const [];
      final presets = raw
          .map((entry) => jsonDecode(entry) as Map<String, dynamic>)
          .map(_SavedVenuePreset.fromJson)
          .where((preset) => preset.venue.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _savedVenuePresets = presets;
        if (_selectedSavedVenueId != null &&
            !_savedVenuePresets.any((p) => p.id == _selectedSavedVenueId)) {
          _selectedSavedVenueId = null;
        }
      });
    } catch (e) {
      debugPrint('Error loading saved venue presets: $e');
    }
  }

  Future<void> _saveCurrentVenuePreset() async {
    final venue = venueCtrl.text.trim();
    if (venue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a venue name before saving it.')),
      );
      return;
    }

    final preset = _SavedVenuePreset(
      venue: venue,
      address: venueAddressCtrl.text.trim(),
      latitude: latitudeCtrl.text.trim(),
      longitude: longitudeCtrl.text.trim(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = [..._savedVenuePresets];
      final existingIndex = updated.indexWhere((p) => p.id == preset.id);
      if (existingIndex >= 0) {
        updated[existingIndex] = preset;
      } else {
        updated.add(preset);
      }

      final encoded = updated.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_savedVenuesPrefsKey(), encoded);

      if (!mounted) return;
      setState(() {
        _savedVenuePresets = updated;
        _selectedSavedVenueId = preset.id;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved venue: ${preset.venue}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save venue: $e')));
    }
  }

  Future<void> _deleteSelectedVenuePreset() async {
    final selectedPreset = _selectedVenuePresetForCurrentInput();
    final selectedId = selectedPreset?.id ?? _selectedSavedVenueId;
    if (selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a saved venue to delete.')),
      );
      return;
    }

    final preset = _savedVenuePresets.cast<_SavedVenuePreset?>().firstWhere(
      (p) => p?.id == selectedId,
      orElse: () => null,
    );
    if (preset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved venue no longer exists.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved venue?'),
        content: Text('Remove "${preset.venue}" from the saved venue list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = _savedVenuePresets
          .where((p) => p.id != selectedId)
          .toList();
      final encoded = updated.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_savedVenuesPrefsKey(), encoded);

      if (!mounted) return;
      setState(() {
        _savedVenuePresets = updated;
        _selectedSavedVenueId = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted venue: ${preset.venue}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete venue: $e')));
    }
  }

  void _applySavedVenuePreset(_SavedVenuePreset preset) {
    setState(() {
      _selectedSavedVenueId = preset.id;
      venueCtrl.text = preset.venue;
      venueAddressCtrl.text = preset.address;
      latitudeCtrl.text = preset.latitude;
      longitudeCtrl.text = preset.longitude;
    });
  }

  void _setVenueFieldsFromPreset(_SavedVenuePreset? preset) {
    venueCtrl.text = preset?.venue ?? '';
    venueAddressCtrl.text = preset?.address ?? '';
    latitudeCtrl.text = preset?.latitude ?? '';
    longitudeCtrl.text = preset?.longitude ?? '';
  }

  void _applyFixedVenuePreset(_SavedVenuePreset? preset) {
    setState(() {
      _selectedSavedVenueId = null;
      _setVenueFieldsFromPreset(preset);
    });
  }

  void _applyFixedVenuePresetForCurrentSelection() {
    _SavedVenuePreset? preset;
    switch (selectedEventType) {
      case 'Race':
        preset = _raceVenuePresets[selectedRace];
        break;
      case 'Cross Country':
        preset =
            _crossCountryVenuePresets[crossCountryRaceNameCtrl.text.trim()];
        break;
      case 'Relay':
        preset = _relayVenuePresets[_selectedRelayFormat];
        break;
    }

    if (!mounted) return;
    setState(() {
      _selectedSavedVenueId = null;
      _setVenueFieldsFromPreset(preset);
    });
  }

  List<_SavedVenuePreset> _matchingVenuePresets(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.length < 2) return const [];

    return _savedVenuePresets.where((preset) {
      final venue = preset.venue.trim().toLowerCase();
      return venue.startsWith(trimmed) && venue != trimmed;
    }).toList();
  }

  _SavedVenuePreset? _selectedVenuePresetForCurrentInput() {
    final venue = venueCtrl.text.trim().toLowerCase();
    if (venue.isEmpty) return null;

    for (final preset in _savedVenuePresets) {
      if (preset.venue.trim().toLowerCase() == venue) {
        return preset;
      }
    }
    return null;
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
      case "Training":
      case "Training 1":
      case "Training 2":
        // New unified Training type (and legacy labels) all
        // use a simple "Training" title for the calendar.
        return "Training";
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
        final suffix = _selectedSpecialEventType;
        if (suffix != null && suffix.trim().isNotEmpty) {
          return "Special Event - ${suffix.trim()}";
        }
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

      if (result.isNotEmpty) {
        // Recompute unseen-event count so Club Hub badge reflects the
        // newly created event (which starts as "unseen").
        await NotificationService.signalLocalEventActivityChanged();
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
    final theme = Theme.of(context);
    final primary = _brandPrimary(theme.colorScheme);

    return Card(
      elevation: 1,
      color: const Color(0xFF0F111A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primary, width: 1),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = _brandPrimary(colorScheme);
    final accent = _brandAccent(colorScheme);

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
                        side: BorderSide(color: primary, width: 1),
                        foregroundColor: primary,
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
                        side: BorderSide(color: primary, width: 1),
                        foregroundColor: primary,
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
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selectedEventType = v);
                    _applyFixedVenuePresetForCurrentSelection();
                  },
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
                    onChanged: (v) {
                      setState(() => selectedRace = v);
                      _applyFixedVenuePreset(_raceVenuePresets[v]);
                    },
                    decoration: const InputDecoration(labelText: "Select Race"),
                  ),
                ),

              // CROSS COUNTRY UI
              if (selectedEventType == "Cross Country")
                _section(
                  "Race Name",
                  Builder(
                    builder: (context) {
                      final current = crossCountryRaceNameCtrl.text.trim();
                      final bool isSeriesRace = _nrrCrossCountryRaces.contains(
                        current,
                      );

                      // For NRR: only use the dropdown when the current value
                      // is one of the Broadland XC races or when blank.
                      final bool useDropdown =
                          _isNRRClub && (current.isEmpty || isSeriesRace);

                      if (!useDropdown) {
                        // Fallback to free-text for non-series races
                        // (e.g., EACCL Race 10).
                        return TextFormField(
                          controller: crossCountryRaceNameCtrl,
                          decoration: const InputDecoration(
                            labelText: "Race Name",
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? "Required" : null,
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: current.isNotEmpty && isSeriesRace
                            ? current
                            : null,
                        decoration: const InputDecoration(
                          labelText: "Race Name",
                        ),
                        items: _nrrCrossCountryRaces
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            crossCountryRaceNameCtrl.text = v;
                          });
                          _applyFixedVenuePreset(_crossCountryVenuePresets[v]);
                        },
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? "Required" : null,
                      );
                    },
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
                          DropdownMenuItem(
                            value: "AlexMoore",
                            child: Text("Alex Moore Relay"),
                          ),
                          DropdownMenuItem(
                            value: "NorwichTriathlon",
                            child: Text("Norwich Triathlon Relay"),
                          ),
                          DropdownMenuItem(
                            value: "Sandringham24",
                            child: Text("Sandringham 24 Relay"),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedRelayFormat = v);
                          _applyFixedVenuePreset(_relayVenuePresets[v]);
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

              // SPECIAL EVENT UI
              if (selectedEventType == "Special Event")
                _section(
                  "Special Event Type",
                  DropdownButtonFormField<String>(
                    value:
                        _selectedSpecialEventType ?? _specialEventTypes.first,
                    items: _specialEventTypes
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSpecialEventType = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Choose special event',
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // HOST / VENUE / DESCRIPTION
              _section(
                "Event Details",
                Builder(
                  builder: (context) {
                    final matchingVenuePresets = selectedEventType == 'Training'
                        ? _matchingVenuePresets(venueCtrl.text)
                        : const <_SavedVenuePreset>[];
                    final selectedPreset =
                        _selectedVenuePresetForCurrentInput();
                    final showVenueSuggestions =
                        selectedEventType == 'Training' &&
                        matchingVenuePresets.isNotEmpty &&
                        selectedPreset == null;

                    return Column(
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
                                orElse: () => <String, dynamic>{
                                  'full_name': '',
                                },
                              );
                              hostCtrl.text =
                                  (match['full_name'] as String?) ?? '';
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
                          onChanged: selectedEventType == 'Training'
                              ? (_) => setState(() {
                                  _selectedSavedVenueId =
                                      _selectedVenuePresetForCurrentInput()?.id;
                                })
                              : null,
                          decoration: const InputDecoration(labelText: "Venue"),
                          validator: (v) =>
                              v!.trim().isEmpty ? "Required" : null,
                        ),
                        if (showVenueSuggestions) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: matchingVenuePresets.map((preset) {
                                return ActionChip(
                                  label: Text(preset.label),
                                  avatar: const Icon(
                                    Icons.place_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      _applySavedVenuePreset(preset),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: venueAddressCtrl,
                          decoration: const InputDecoration(
                            labelText: "Venue Address",
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: latitudeCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      signed: true,
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: "Lat (optional)",
                                  hintText: "52.9501",
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: longitudeCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      signed: true,
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: "Long (optional)",
                                  hintText: "1.3012",
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (selectedEventType == 'Training') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saveCurrentVenuePreset,
                                  icon: const Icon(Icons.bookmark_add_outlined),
                                  label: const Text('Save Venue'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: selectedPreset == null
                                      ? null
                                      : _deleteSelectedVenuePreset,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Unsave Venue'),
                                ),
                              ),
                            ],
                          ),
                        ],
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
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              /// DATE & TIME
              Card(
                elevation: 1,
                color: const Color(0xFF0F111A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: primary, width: 1),
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
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: accent, width: 1),
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
                                  side: BorderSide(color: accent, width: 1),
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
                    side: BorderSide(color: primary, width: 1),
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

  Color _brandPrimary(ColorScheme scheme) {
    final base = scheme.primary;
    final luminance = base.computeLuminance();
    if (luminance > 0.85) {
      // Fallback to NNBR yellow when primary is too close to white.
      return const Color(0xFFFFD300);
    }
    return base;
  }

  Color _brandAccent(ColorScheme scheme) {
    final base = scheme.secondary;
    final luminance = base.computeLuminance();
    if (luminance > 0.85) {
      // Fallback to NNBR blue when secondary is too close to white.
      return const Color(0xFF0057B7);
    }
    return base;
  }
}
