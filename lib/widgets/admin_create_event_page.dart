import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/menu/races_eaccl_page_clean.dart';
import 'package:runrank/menu/handicap_series_page.dart';
import 'package:runrank/menu/rnr_ekiden_eaccl_page.dart';
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

  double? get latitudeValue => double.tryParse(latitude);
  double? get longitudeValue => double.tryParse(longitude);

  bool get hasValidCoordinates {
    final lat = latitudeValue;
    final lon = longitudeValue;
    return lat != null &&
        lon != null &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180;
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
  final TimeOfDay? initialTime;
  final String? initialVenue;
  final String? initialRaceName;
  final String? initialVenueAddress;
  final String? initialRelayFormat;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialSignatureImageAsset;

  const AdminCreateEventPage({
    super.key,
    required this.userRole,
    this.initialEventType,
    this.initialHandicapDistance,
    this.initialDate,
    this.initialTime,
    this.initialVenue,
    this.initialRaceName,
    this.initialVenueAddress,
    this.initialRelayFormat,
    this.initialLatitude,
    this.initialLongitude,
    this.initialSignatureImageAsset,
  });

  @override
  State<AdminCreateEventPage> createState() => _AdminCreateEventPageState();
}

class _AdminCreateEventPageState extends State<AdminCreateEventPage> {
  static const Map<String, _SavedVenuePreset> _raceVenuePresets = {
    'Holt 10K': _SavedVenuePreset(
      venue: 'Gresham School',
      address: 'Cromer Road, Holt',
      latitude: '52.910199',
      longitude: '1.104856',
    ),
    'Worstead 5M': _SavedVenuePreset(
      venue: 'Worstead Village Hall',
      address: 'North Walsham',
      latitude: '52.783583',
      longitude: '1.410747',
    ),
    'Chase The Train': _SavedVenuePreset(
      venue: 'Bure Valley Railway',
      address: 'Aylsham Station',
      latitude: '52.791254',
      longitude: '1.254838',
    ),
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
    'Broadland Country Park XC Series 1': _SavedVenuePreset(
      venue: 'Oakland Organic Egg Farm',
      address: 'Sandy Ln, Horsford',
      latitude: '52.7108107164322',
      longitude: '1.2260404278394894',
    ),
    'Broadland Country Park XC Series 2': _SavedVenuePreset(
      venue: 'Oakland Organic Egg Farm',
      address: 'Sandy Ln, Horsford',
      latitude: '52.7108107164322',
      longitude: '1.2260404278394894',
    ),
    'Broadland Country Park XC Series 3': _SavedVenuePreset(
      venue: 'Oakland Organic Egg Farm',
      address: 'Sandy Ln, Horsford',
      latitude: '52.7108107164322',
      longitude: '1.2260404278394894',
    ),

    // EACCL preset venues (used when creating events from the EACCL page)
    'EACCL Race 1': _SavedVenuePreset(
      venue: 'Chilton Fields (Stowmarket) Rugby Club',
      address: 'IP14 1SZ',
      latitude: '52.194928943614755',
      longitude: '0.9736349359399866',
    ),
    'EACCL Race 2': _SavedVenuePreset(
      venue: 'Mousehold Heath',
      address: 'NR3 4JB',
      latitude: '52.6456293816159',
      longitude: '1.3053020539832265',
    ),
    'EACCL Race 3': _SavedVenuePreset(
      venue: 'Cart Gap',
      address: 'NR12 0QL',
      latitude: '52.813993848969545',
      longitude: '1.5559508723398736',
    ),
    'EACCL Race 4': _SavedVenuePreset(
      venue: 'Whitwell Station',
      address: 'NR10 4GA',
      latitude: '52.75213734380336',
      longitude: '1.0976076815697193',
    ),
    'EACCL Race 5': _SavedVenuePreset(
      venue: 'Broadland Country Park',
      address: 'NR10 3FB',
      latitude: '52.70864077472078',
      longitude: '1.2325142321897717',
    ),
    'EACCL Race 6': _SavedVenuePreset(
      venue: 'Woburn Farm, Corton',
      address: 'NR32 5LE',
      latitude: '52.52188865016863',
      longitude: '1.7337329963973074',
    ),
    'EACCL Race 7': _SavedVenuePreset(
      venue: 'Cromer',
      address: 'NR27 9AU',
      latitude: '52.9336054467087',
      longitude: '1.2898943747112603',
    ),
    'EACCL Race 8': _SavedVenuePreset(
      venue: 'Ladybelt Country Park',
      address: 'NR14 8HX',
      latitude: '52.57296936611113',
      longitude: '1.21047899764725',
    ),
    'EACCL Race 9': _SavedVenuePreset(
      venue: 'Cawston Park',
      address: 'NR10 4JD',
      latitude: '52.7758986780014',
      longitude: '1.2065194249995728',
    ),
    'EACCL Race 10': _SavedVenuePreset(
      venue: 'High Lodge, Thetford Forest',
      address: 'IP27 0AF',
      latitude: '52.43419930176653',
      longitude: '0.6619943176235326',
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
  };

  static const Map<String, _SavedVenuePreset> _handicapVenuePresets = {
    '5K': _SavedVenuePreset(
      venue: 'The Avenue',
      address: 'Cromer',
      latitude: '52.912648',
      longitude: '1.314740',
    ),
    'Beach Run': _SavedVenuePreset(
      venue: 'Beech Road',
      address: 'Mundesley',
      latitude: '52.877383',
      longitude: '1.438650',
    ),
    '10M': _SavedVenuePreset(
      venue: 'Hillside',
      address: 'Norwich Road, Cromer',
      latitude: '52.918606',
      longitude: '1.307063',
    ),
    '5M': _SavedVenuePreset(
      venue: 'Aldborough',
      address: 'Norwich',
      latitude: '52.861983',
      longitude: '1.242988',
    ),
    '10K': _SavedVenuePreset(
      venue: 'Hillside',
      address: 'Norwich Road, Cromer',
      latitude: '52.919162',
      longitude: '1.305687',
    ),
    '7M': _SavedVenuePreset(
      venue: 'Woodfield/Kelling Roads',
      address: 'Holt',
      latitude: '52.911485',
      longitude: '1.097483',
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
  bool get _isNNBRClub =>
      _clubName != null &&
      _clubName!.toLowerCase().contains('north norfolk beach runners');

  static const List<String> _nrrTrainingEventTypes = <String>[
    'Recovery Monday',
    'Mousehold Monday',
    'Tuesday Efforts 1',
    'Tuesday Efforts 2',
    'Road Run Thursday',
    'Track Session',
  ];

  static const List<String> _legacyNrrTrainingEventTypes = <String>[
    'Tuesday Efforts',
    'Efforts Tuesday',
    'Coached Tuesday',
    'Road Route Thursday',
    'Paul Evans Session',
    'Paul Evan Session',
  ];

  static String _normaliseNrrTrainingEventType(String eventType) {
    switch (eventType) {
      case 'Tuesday Efforts':
      case 'Efforts Tuesday':
      case 'Coached Tuesday':
        return 'Tuesday Efforts 1';
      case 'Road Route Thursday':
        return 'Road Run Thursday';
      case 'Paul Evans Session':
      case 'Paul Evan Session':
        return 'Track Session';
      default:
        return eventType;
    }
  }

  static bool _isNrrTrainingEventType(String eventType) =>
      _nrrTrainingEventTypes.contains(eventType) ||
      _legacyNrrTrainingEventTypes.contains(eventType);

  static String _relayFormatDisplayName(String relayFormat) {
    switch (relayFormat) {
      case 'Ekiden':
        return 'Ekiden';
      case 'AlexMoore':
        return 'Alex Moore';
      case 'RNR':
      default:
        return 'RNR';
    }
  }

  bool get _usesTrainingDetails =>
      _resolvedEventType == 'Training' ||
      selectedEventType == 'Training 1' ||
      selectedEventType == 'Training 2' ||
      _nrrTrainingEventTypes.contains(_resolvedEventType);

  bool get _supportsWeeklyTrainingRepeat =>
      _isNRRClub && selectedEventType == 'Training';

  bool get _usesHandicapDetails =>
      _resolvedEventType == 'Handicap Series' ||
      _resolvedEventType == 'One Mile Handicap';

  String get _resolvedEventType => _isNRRClub && selectedEventType == 'Training'
      ? _selectedNrrTrainingEventType
      : selectedEventType;

  // Host selection
  List<Map<String, dynamic>> _hosts = [];
  String? _selectedHostId;
  String? _currentUserId;
  List<_SavedVenuePreset> _savedVenuePresets = [];
  String? _selectedSavedVenueId;

  @override
  void initState() {
    super.initState();

    adminTypes = [
      "Training",
      "Race",
      "Relay",
      "Cross Country",
      "Handicap Series",
      "Special Event",
    ];

    socialTypes = ["Social Run", "Parkrun Tourism"];

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
      if (_isNrrTrainingEventType(initType)) {
        selectedEventType = "Training";
        _selectedNrrTrainingEventType = _normaliseNrrTrainingEventType(
          initType,
        );
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
    if (widget.initialTime != null) {
      selectedTime = widget.initialTime;
    }
    if (widget.initialVenue != null) {
      venueCtrl.text = widget.initialVenue!;
    }
    if (widget.initialRaceName != null) {
      if (selectedEventType == 'Race') {
        selectedRace = widget.initialRaceName!;
      } else {
        crossCountryRaceNameCtrl.text = widget.initialRaceName!;
      }
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

    // Default time unless explicitly changed. Training defaults to 18:30.
    selectedTime ??= _defaultTimeForCurrentSelection();

    _loadHosts();
  }

  String selectedEventType = "";
  String selectedCategory = "";
  String _selectedNrrTrainingEventType = _nrrTrainingEventTypes.first;
  String _selectedRelayFormat = "RNR";
  bool _repeatWeeklyTraining = false;
  int _trainingRepeatWeeks = 1;
  bool _savingEvent = false;

  bool get _isSignatureCreatedRaceType =>
      selectedEventType == "Race" || selectedEventType == "Cross Country";

  bool get _wasOpenedForDirectEventCreation =>
      widget.initialEventType != null ||
      widget.initialRaceName != null ||
      widget.initialRelayFormat != null ||
      widget.initialDate != null ||
      widget.initialVenue != null;

  TimeOfDay _defaultTimeForCurrentSelection() {
    return selectedEventType.startsWith('Training')
        ? const TimeOfDay(hour: 18, minute: 30)
        : const TimeOfDay(hour: 14, minute: 30);
  }

  void _openEventSourcePage(String eventType) {
    Widget page;
    switch (eventType) {
      case 'Race':
        page = const RacesEacclPage();
        break;
      case 'Relay':
        page = const RnrEkidenEacclPage();
        break;
      case 'Cross Country':
        page = const RnrEkidenEacclPage(initialTabIndex: 5);
        break;
      case 'Handicap Series':
        page = const HandicapSeriesPage();
        break;
      default:
        return;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  List<String> get _eventTypeDropdownItems {
    final items = selectedCategory == "admin" ? adminTypes : socialTypes;
    if (selectedCategory == "admin" &&
        _isSignatureCreatedRaceType &&
        !items.contains(selectedEventType)) {
      return [selectedEventType, ...items];
    }
    return items;
  }

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
  final venueFocusNode = FocusNode();
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

  List<String> get _raceDropdownItems {
    final items = <String>[...raceNames];
    final current = selectedRace?.trim();
    if (current != null && current.isNotEmpty && !items.contains(current)) {
      items.insert(0, current);
    }
    return items;
  }

  // NRR-specific Cross Country series races
  static const List<String> _nrrCrossCountryRaces = <String>[
    'Broadland Country Park XC Series 1',
    'Broadland Country Park XC Series 2',
    'Broadland Country Park XC Series 3',
  ];

  Future<void> _loadHosts() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      _currentUserId = currentUserId;

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
            "Relay",
            "Cross Country",
            "One Mile Handicap",
            "Special Event",
          ];

          // NRR signature races for the Race dropdown.
          raceNames = ["Wroxham 5K", "Dinosaur Dash"];
        } else {
          // Default (NNBR and other clubs).
          adminTypes = [
            if (_isNNBRClub) ...["Training 1", "Training 2"] else "Training",
            "Race",
            "Relay",
            "Cross Country",
            "Handicap Series",
            "Special Event",
          ];

          raceNames = ["Holt 10K", "Worstead 5M", "Chase The Train"];
        }

        if (selectedCategory == 'admin' &&
            !adminTypes.contains(selectedEventType) &&
            !_isSignatureCreatedRaceType) {
          if (_isNrrTrainingEventType(selectedEventType)) {
            _selectedNrrTrainingEventType = _normaliseNrrTrainingEventType(
              selectedEventType,
            );
          }
          selectedEventType = adminTypes.first;
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

  void _selectCurrentUserAsHost() {
    final currentUserId = _currentUserId ?? supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final currentHost = _hosts.firstWhere(
      (h) => h['id'] == currentUserId,
      orElse: () => <String, dynamic>{},
    );

    _selectedHostId = currentUserId;
    final currentName = (currentHost['full_name'] as String?)?.trim();
    if (currentName != null && currentName.isNotEmpty) {
      hostCtrl.text = currentName;
    }
  }

  String _savedVenuesPrefsKey() {
    final rawClub = (_clubName ?? 'default_club').trim().toLowerCase();
    final safeClub = rawClub.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'admin_saved_venues_$safeClub';
  }

  String _savedVenueClubKey() {
    return NotificationService.canonicalClubName(_clubName).trim();
  }

  _SavedVenuePreset? _presetFromSharedVenueRow(Map<String, dynamic> row) {
    final venue = (row['venue'] as String? ?? '').trim();
    final latitude = row['latitude'];
    final longitude = row['longitude'];
    if (venue.isEmpty || latitude == null || longitude == null) {
      return null;
    }

    final preset = _SavedVenuePreset(
      venue: venue,
      address: (row['address'] as String? ?? '').trim(),
      latitude: latitude.toString(),
      longitude: longitude.toString(),
    );

    return preset.hasValidCoordinates ? preset : null;
  }

  Future<List<_SavedVenuePreset>> _loadSharedVenuePresets() async {
    final clubKey = _savedVenueClubKey();
    if (clubKey.isEmpty) return const [];

    final rows = await supabase
        .from('saved_venues')
        .select('venue, address, latitude, longitude')
        .eq('club', clubKey)
        .order('venue');

    final presets = <_SavedVenuePreset>[];
    for (final row in rows as List) {
      final preset = _presetFromSharedVenueRow(
        Map<String, dynamic>.from(row as Map),
      );
      if (preset != null) {
        presets.add(preset);
      }
    }
    return presets;
  }

  Future<List<_SavedVenuePreset>> _loadLocalVenuePresets() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = {_savedVenuesPrefsKey()};

    final presets = <_SavedVenuePreset>[];
    for (final key in keys) {
      final raw = prefs.getStringList(key) ?? const [];
      for (final entry in raw) {
        try {
          final preset = _SavedVenuePreset.fromJson(
            jsonDecode(entry) as Map<String, dynamic>,
          );
          if (preset.venue.isNotEmpty && preset.hasValidCoordinates) {
            presets.add(preset);
          }
        } catch (e) {
          debugPrint('Error decoding saved venue preset from "$key": $e');
        }
      }
    }
    return presets;
  }

  Future<void> _loadSavedVenuePresets() async {
    try {
      final presetsById = <String, _SavedVenuePreset>{};

      try {
        for (final preset in await _loadSharedVenuePresets()) {
          presetsById[preset.id] = preset;
        }
      } catch (e) {
        debugPrint('Error loading shared venue presets: $e');
      }

      for (final preset in await _loadLocalVenuePresets()) {
        presetsById.putIfAbsent(preset.id, () => preset);
      }

      final presets =
          presetsById.values
              .where((preset) => preset.hasValidCoordinates)
              .toList()
            ..sort(
              (a, b) => a.venue.trim().toLowerCase().compareTo(
                b.venue.trim().toLowerCase(),
              ),
            );

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

  Future<void> _saveVenuePresetLocally(_SavedVenuePreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [..._savedVenuePresets];
    final existingIndex = updated.indexWhere((p) => p.id == preset.id);
    if (existingIndex >= 0) {
      updated[existingIndex] = preset;
    } else {
      updated.add(preset);
    }

    final encoded = updated
        .where((p) => p.hasValidCoordinates)
        .map((p) => jsonEncode(p.toJson()))
        .toList();
    await prefs.setStringList(_savedVenuesPrefsKey(), encoded);
  }

  Future<void> _saveVenuePresetToSupabase(_SavedVenuePreset preset) async {
    final userId = supabase.auth.currentUser?.id;
    final clubKey = _savedVenueClubKey();
    final latitude = preset.latitudeValue;
    final longitude = preset.longitudeValue;
    if (userId == null ||
        clubKey.isEmpty ||
        latitude == null ||
        longitude == null) {
      throw StateError('Missing user, club, or venue coordinates.');
    }

    await supabase.from('saved_venues').upsert({
      'club': clubKey,
      'venue': preset.venue.trim(),
      'address': preset.address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'created_by': userId,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'club,venue,address');
  }

  Future<void> _saveCurrentVenuePreset() async {
    final venue = venueCtrl.text.trim();
    if (venue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a venue name before saving it.')),
      );
      return;
    }

    final latitude = double.tryParse(latitudeCtrl.text.trim());
    final longitude = double.tryParse(longitudeCtrl.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add valid latitude and longitude before saving this venue.',
          ),
        ),
      );
      return;
    }

    final preset = _SavedVenuePreset(
      venue: venue,
      address: venueAddressCtrl.text.trim(),
      latitude: latitude.toString(),
      longitude: longitude.toString(),
    );

    try {
      var savedForClub = true;
      try {
        await _saveVenuePresetToSupabase(preset);
      } catch (e) {
        savedForClub = false;
        debugPrint('Failed to save shared venue preset: $e');
      }

      await _saveVenuePresetLocally(preset);
      await _loadSavedVenuePresets();

      if (!mounted) return;
      setState(() {
        _selectedSavedVenueId = preset.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedForClub
                ? 'Saved venue for club: ${preset.venue}'
                : 'Saved venue on this device only until shared venues are enabled.',
          ),
        ),
      );
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

      final clubKey = _savedVenueClubKey();
      if (clubKey.isNotEmpty) {
        try {
          await supabase
              .from('saved_venues')
              .delete()
              .eq('club', clubKey)
              .eq('venue', preset.venue)
              .eq('address', preset.address);
        } catch (e) {
          debugPrint('Failed to delete shared saved venue: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _savedVenuePresets = updated;
        _selectedSavedVenueId = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted venue: ${preset.venue}')));
    } catch (e) {
      if (!mounted) return;
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
      case 'Handicap Series':
        preset = _handicapVenuePresets[selectedHandicapDistance];
        break;
    }

    if (!mounted || preset == null) return;
    setState(() {
      _selectedSavedVenueId = null;
      _setVenueFieldsFromPreset(preset);
    });
  }

  List<_SavedVenuePreset> _matchingVenuePresets(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];

    final matches = _savedVenuePresets.where((preset) {
      final venue = preset.venue.trim().toLowerCase();
      return venue != trimmed && venue.contains(trimmed);
    }).toList();

    matches.sort((a, b) {
      final aVenue = a.venue.trim().toLowerCase();
      final bVenue = b.venue.trim().toLowerCase();
      final aStartsWith = aVenue.startsWith(trimmed);
      final bStartsWith = bVenue.startsWith(trimmed);

      if (aStartsWith != bStartsWith) {
        return aStartsWith ? -1 : 1;
      }

      return aVenue.compareTo(bVenue);
    });

    return matches;
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
    venueFocusNode.dispose();
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
    final eventType = _resolvedEventType;
    switch (eventType) {
      case "Training":
        return "Training";
      case "Training 1":
        return "Training 1";
      case "Training 2":
        return "Training 2";
      case "Recovery Monday":
      case "Mousehold Monday":
      case "Tuesday Efforts 1":
      case "Tuesday Efforts 2":
      case "Tuesday Efforts":
      case "Efforts Tuesday":
      case "Road Run Thursday":
      case "Track Session":
      case "Coached Tuesday":
      case "Road Route Thursday":
      case "Paul Evans Session":
      case "Paul Evan Session":
        return eventType;
      case "One Mile Handicap":
        return "One Mile Handicap";
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
      case "Parkrun Tourism":
        return "Parkrun Tourism";
      default:
        return eventType;
    }
  }

  Future<void> saveEvent() async {
    if (_savingEvent) return;
    if (!_formKey.currentState!.validate()) return;

    if (selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a date")));
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a time")));
      return;
    }

    final timeString =
        "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}";

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
      final relayLabel = _relayFormatDisplayName(_selectedRelayFormat);
      if (teamName.isEmpty) {
        relayTeamValue = relayLabel;
      } else {
        relayTeamValue = "$relayLabel: $teamName";
      }
    }

    final eventTypeForSave = _resolvedEventType;
    final repeatCount = _supportsWeeklyTrainingRepeat && _repeatWeeklyTraining
        ? _trainingRepeatWeeks
        : 1;
    final createdByUserId = supabase.auth.currentUser?.id;
    if (selectedCategory == "social") {
      _selectCurrentUserAsHost();
    }
    final hostNameForSave = hostCtrl.text.trim();
    final hostUserIdForSave = _selectedHostId;
    String dateIso(DateTime date) => date.toIso8601String().split("T").first;

    final maps = List<Map<String, dynamic>>.generate(repeatCount, (index) {
      final eventDate = selectedDate!.add(Duration(days: index * 7));
      return {
        "event_type": eventTypeForSave.toLowerCase().replaceAll(" ", "_"),
        "training_number": eventTypeForSave == "Training 1"
            ? 1
            : eventTypeForSave == "Training 2"
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
        "date": dateIso(eventDate),
        "time": timeString,
        "host_or_director": hostNameForSave,
        "host_user_id": hostUserIdForSave,
        "venue": venueCtrl.text.trim(),
        "venue_address": venueAddressCtrl.text.trim(),
        "description": descriptionCtrl.text.trim(),
        if (widget.initialSignatureImageAsset != null)
          "signature_image_asset": widget.initialSignatureImageAsset,
        "latitude": latitude,
        "longitude": longitude,
        "marshal_call_date":
            (selectedEventType == "Race" ||
                selectedEventType == "Cross Country" ||
                _usesHandicapDetails)
            ? marshalCallDate?.toIso8601String().split("T").first
            : null,
        "expected_time_required":
            _usesHandicapDetails || selectedEventType == "Relay" ? true : false,
        "created_by": createdByUserId,
      };
    });

    setState(() => _savingEvent = true);

    try {
      final result = await supabase.from("club_events").insert(maps).select();

      if (!mounted) return;

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      if (result.isNotEmpty) {
        // Recompute unseen-event count so Club Hub badge reflects the
        // newly created event (which starts as "unseen").
        unawaited(NotificationService.signalLocalEventActivityChanged());
      }

      if (mounted) {
        navigator.pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              repeatCount == 1
                  ? "Event created successfully!"
                  : "$repeatCount weekly training events created successfully!",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text("Failed: $e")));
      setState(() => _savingEvent = false);
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
                        _selectCurrentUserAsHost();
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
                  items: _eventTypeDropdownItems
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: _isSignatureCreatedRaceType
                      ? null
                      : (v) {
                          if (v == null) return;
                          if (!_wasOpenedForDirectEventCreation &&
                              (v == 'Race' ||
                                  v == 'Relay' ||
                                  v == 'Cross Country' ||
                                  v == 'Handicap Series')) {
                            _openEventSourcePage(v);
                            return;
                          }
                          setState(() {
                            selectedEventType = v;
                            if (_isNRRClub && v == 'Training') {
                              _selectedNrrTrainingEventType =
                                  _nrrTrainingEventTypes.first;
                            }
                            selectedTime = _defaultTimeForCurrentSelection();
                          });
                          _applyFixedVenuePresetForCurrentSelection();
                        },
                ),
              ),

              const SizedBox(height: 12),

              // NRR TRAINING UI
              if (_isNRRClub && selectedEventType == "Training")
                _section(
                  "Training Event",
                  DropdownButtonFormField<String>(
                    initialValue: _selectedNrrTrainingEventType,
                    items: _nrrTrainingEventTypes
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedNrrTrainingEventType = v);
                    },
                    decoration: const InputDecoration(
                      labelText: "Select training event",
                    ),
                  ),
                ),

              if (_isNRRClub && selectedEventType == "Training")
                const SizedBox(height: 12),

              // RACE UI
              if (selectedEventType == "Race")
                _section(
                  "Race Name",
                  DropdownButtonFormField<String>(
                    initialValue: selectedRace,
                    items: _raceDropdownItems
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
                        initialValue: current.isNotEmpty && isSeriesRace
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
                    onChanged: (v) {
                      setState(() => selectedHandicapDistance = v);
                      _applyFixedVenuePreset(_handicapVenuePresets[v]);
                    },
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
                        initialValue: _selectedRelayFormat,
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
                    initialValue:
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
                    final supportsSavedVenues =
                        _usesTrainingDetails ||
                        selectedEventType == 'Parkrun Tourism';
                    final matchingVenuePresets = supportsSavedVenues
                        ? _matchingVenuePresets(venueCtrl.text)
                        : const <_SavedVenuePreset>[];
                    final visibleVenuePresets = supportsSavedVenues
                        ? (venueCtrl.text.trim().isEmpty
                              ? const <_SavedVenuePreset>[]
                              : matchingVenuePresets)
                        : const <_SavedVenuePreset>[];
                    final selectedPreset =
                        _selectedVenuePresetForCurrentInput();
                    final showVenueSuggestions =
                        supportsSavedVenues &&
                        venueFocusNode.hasFocus &&
                        visibleVenuePresets.isNotEmpty &&
                        selectedPreset == null;

                    return Column(
                      children: [
                        if (selectedCategory == "social")
                          TextFormField(
                            controller: hostCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: "Host / Director",
                              suffixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          )
                        else
                          DropdownButtonFormField<String>(
                            key: ValueKey(_selectedHostId),
                            initialValue: _selectedHostId,
                            decoration: const InputDecoration(
                              labelText: "Host / Director",
                            ),
                            items: _hosts
                                .where((h) => h['is_admin'] as bool? ?? false)
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
                          focusNode: venueFocusNode,
                          onChanged: supportsSavedVenues
                              ? (_) => setState(() {
                                  _selectedSavedVenueId =
                                      _selectedVenuePresetForCurrentInput()?.id;
                                })
                              : null,
                          onTap: supportsSavedVenues
                              ? () => setState(() {})
                              : null,
                          decoration: const InputDecoration(labelText: "Venue"),
                          validator: (v) =>
                              v!.trim().isEmpty ? "Required" : null,
                        ),
                        if (supportsSavedVenues)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _savedVenuePresets.isEmpty
                                    ? 'No saved venues found yet.'
                                    : '${_savedVenuePresets.length} saved venue${_savedVenuePresets.length == 1 ? '' : 's'} available',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        if (showVenueSuggestions) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF151922),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: visibleVenuePresets.map((preset) {
                                final isLast = identical(
                                  preset,
                                  visibleVenuePresets.last,
                                );
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.place_outlined,
                                        size: 20,
                                      ),
                                      title: Text(preset.venue),
                                      subtitle: preset.address.isEmpty
                                          ? null
                                          : Text(
                                              preset.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      onTap: () {
                                        _applySavedVenuePreset(preset);
                                        venueFocusNode.unfocus();
                                      },
                                    ),
                                    if (!isLast)
                                      const Divider(height: 1, thickness: 0.5),
                                  ],
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
                        if (supportsSavedVenues) ...[
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
                                  initialTime: selectedTime ?? TimeOfDay.now(),
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
                      ),
                      if (_supportsWeeklyTrainingRepeat) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: _repeatWeeklyTraining,
                          onChanged: (value) {
                            setState(() {
                              _repeatWeeklyTraining = value;
                              if (!value) {
                                _trainingRepeatWeeks = 1;
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Create weekly repeats',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Use the selected date as the first session, then add one each week.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        if (_repeatWeeklyTraining)
                          DropdownButtonFormField<int>(
                            initialValue: _trainingRepeatWeeks,
                            decoration: const InputDecoration(
                              labelText: 'Number of weekly sessions',
                            ),
                            items: List<int>.generate(12, (index) => index + 1)
                                .map(
                                  (count) => DropdownMenuItem<int>(
                                    value: count,
                                    child: Text('$count sessions'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _trainingRepeatWeeks = value);
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // MARSHAL CALL DATE
              if (selectedEventType == "Race" ||
                  selectedEventType == "Cross Country" ||
                  _usesHandicapDetails)
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
                  onPressed: _savingEvent ? null : saveEvent,
                  icon: _savingEvent
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_savingEvent ? "Saving..." : "Save Event"),
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
