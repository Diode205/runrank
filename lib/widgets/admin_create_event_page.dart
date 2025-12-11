import 'package:flutter/material.dart';
import 'package:runrank/services/event_service.dart';
import 'package:runrank/services/notification_service.dart';

class AdminCreateEventPage extends StatefulWidget {
  final String userRole; // ⭐ NEW

  const AdminCreateEventPage({
    super.key,
    required this.userRole, // ⭐ NEW
  });

  @override
  State<AdminCreateEventPage> createState() => _AdminCreateEventPageState();
}

class _AdminCreateEventPageState extends State<AdminCreateEventPage> {
  final _formKey = GlobalKey<FormState>();

  // ⭐ UPDATED: No longer a single dropdown.
  // Instead we'll track two sources:
  String? _adminEventType; // training, event, race, handicap, relay
  String? _socialEventType; // Social Run, Meet & Drink, etc.

  // Shared fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _leadHostDirectorController =
      TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _venueAddressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Training-specific
  int _trainingNumber = 1;

  // Race-specific
  String _selectedRaceName = 'Holt 10K';

  // Handicap-specific
  String _selectedHandicapDistance = '5 km';

  // Relay-specific
  String _relayTeam = 'A';

  // Dates & times
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _marshalCallDate;

  @override
  void dispose() {
    _titleController.dispose();
    _leadHostDirectorController.dispose();
    _venueController.dispose();
    _venueAddressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  static const _raceNames = [
    'Holt 10K',
    'Worstead 5M',
    'Chase The Train',
    'Boxing Day Dip',
  ];

  static const _handicapDistances = [
    '5 km',
    '5 miles',
    'Beach Race',
    '10 km',
    '10 miles',
    '7 miles',
  ];

  // SOCIAL OPTIONS ⭐ NEW
  static const _socialTypes = [
    'Social Run',
    'Meet & Drink',
    'Walk / Cycle / Swim',
    'Other',
  ];

  // ADMIN OPTIONS ⭐ NEW
  static const _adminTypes = ['training', 'event', 'race', 'handicap', 'relay'];

  // -------------------------------
  // Date / Time Pickers
  // -------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickMarshalCallDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _marshalCallDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _marshalCallDate = picked);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Pick date';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return 'Pick time';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // -------------------------------
  // Save Logic (UPDATED FOR ROLES)
  // -------------------------------

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    // Determine actual event type
    final isAdmin = widget.userRole == 'admin';

    String? finalType = _adminEventType ?? _socialEventType;

    if (finalType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an activity type')),
      );
      return;
    }

    // ⭐ BLOCK readers from selecting admin-only types
    if (!isAdmin && _adminEventType != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only admins can create Training, Event, Race, Handicap, Relay',
          ),
        ),
      );
      return;
    }

    // Convert social names to lowercase DB types
    if (!isAdmin) {
      finalType = finalType.toLowerCase(); // e.g. "social run"
    }

    final fullDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final hostDir = _leadHostDirectorController.text.trim();
    final venue = _venueController.text.trim();
    final venueAddress = _venueAddressController.text.trim();
    final description = _descriptionController.text.trim();

    // ----- TITLE GENERATION -----
    String title;
    String? raceName;
    String? handicapDistance;
    int? trainingNumber;
    String? relayTeam;

    switch (finalType) {
      case 'training':
        trainingNumber = _trainingNumber;
        final custom = _titleController.text.trim();
        title = custom.isEmpty
            ? 'Training $trainingNumber'
            : 'Training $trainingNumber — $custom';
        break;
      case 'race':
        raceName = _selectedRaceName;
        title = 'Race: $raceName';
        break;
      case 'handicap':
        handicapDistance = _selectedHandicapDistance;
        title = 'Handicap ($handicapDistance)';
        break;
      case 'relay':
        relayTeam = _relayTeam;
        title = 'RNR Relay – Team $relayTeam';
        break;
      default:
        title = _titleController.text.trim().isEmpty
            ? finalType[0].toUpperCase() + finalType.substring(1)
            : _titleController.text.trim();
    }

    // ---------------------------
    // Create event in Supabase
    // ---------------------------

    try {
      final eventId = await EventService.createEvent(
        eventType: finalType,
        trainingNumber: trainingNumber,
        raceName: raceName,
        handicapDistance: handicapDistance,
        title: title,
        dateTime: fullDateTime,
        hostOrDirector: hostDir,
        venue: venue,
        venueAddress: venueAddress.isEmpty ? null : venueAddress,
        description: description,
        marshalCallDate: _marshalCallDate,
        relayTeam: relayTeam,
      );

      final friendlyDate =
          '${fullDateTime.day.toString().padLeft(2, '0')}/${fullDateTime.month.toString().padLeft(2, '0')}';
      final friendlyTime =
          '${fullDateTime.hour.toString().padLeft(2, '0')}:${fullDateTime.minute.toString().padLeft(2, '0')}';

      final message =
          '$title on $friendlyDate at $friendlyTime'
          '${venue.isNotEmpty ? ' · $venue' : ''}';

      await NotificationService.notifyAllUsers(
        title: 'New $finalType created',
        body: message,
        eventId: eventId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved $finalType: $title')));

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save event: $e')));
    }
  }

  // -------------------------------
  // UI
  // -------------------------------

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userRole == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Create Club Activity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⭐ ADMIN DROPDOWN (disabled for readers)
              Opacity(
                opacity: isAdmin ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !isAdmin,
                  child: DropdownButtonFormField<String>(
                    value: _adminEventType,
                    decoration: const InputDecoration(
                      labelText: 'Admin-only activities',
                    ),
                    items: _adminTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type[0].toUpperCase() + type.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _adminEventType = v;
                        _socialEventType = null;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ⭐ SOCIAL DROPDOWN
              DropdownButtonFormField<String>(
                value: _socialEventType,
                decoration: const InputDecoration(
                  labelText: 'Social activities (all members)',
                ),
                items: _socialTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _socialEventType = v;
                    _adminEventType = null;
                  });
                },
              ),

              const SizedBox(height: 20),

              // ⭐ DYNAMIC FIELDS, based on admin type
              if (_adminEventType == 'training') ...[
                Row(
                  children: [
                    const Text('Training number:'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _trainingNumber,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Training 1')),
                        DropdownMenuItem(value: 2, child: Text('Training 2')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _trainingNumber = v);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Optional label (e.g. Intervals on the hill)',
                  ),
                ),
              ],

              if (_adminEventType == 'event') ...[
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Event name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],

              if (_adminEventType == 'race') ...[
                DropdownButtonFormField<String>(
                  value: _selectedRaceName,
                  items: _raceNames
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedRaceName = v);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Race name'),
                ),
              ],

              if (_adminEventType == 'handicap') ...[
                DropdownButtonFormField<String>(
                  value: _selectedHandicapDistance,
                  items: _handicapDistances
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedHandicapDistance = v);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Handicap distance',
                  ),
                ),
              ],

              if (_adminEventType == 'relay') ...[
                DropdownButtonFormField<String>(
                  value: _relayTeam,
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('Team A')),
                    DropdownMenuItem(value: 'B', child: Text('Team B')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _relayTeam = v);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Relay Team'),
                ),
              ],

              const SizedBox(height: 16),

              // -------------------------------
              // DATE + TIME
              // -------------------------------
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_formatDate(_selectedDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_formatTime(_selectedTime)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // -------------------------------
              // HOST / DIRECTOR
              // -------------------------------
              TextFormField(
                controller: _leadHostDirectorController,
                decoration: InputDecoration(
                  labelText:
                      (_adminEventType == 'race' ||
                          _adminEventType == 'handicap')
                      ? 'Run Director(s)'
                      : _adminEventType == 'training'
                      ? 'Training lead name'
                      : 'Host',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // Venue
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(labelText: 'Venue'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _venueAddressController,
                decoration: const InputDecoration(labelText: 'Venue address'),
              ),

              const SizedBox(height: 16),

              if (_adminEventType == 'race' || _adminEventType == 'handicap')
                InkWell(
                  onTap: _pickMarshalCallDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Marshal call date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _marshalCallDate == null
                          ? 'Pick date'
                          : _formatDate(_marshalCallDate),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onSave,
                  icon: const Icon(Icons.save),
                  label: const Text('Save activity'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
