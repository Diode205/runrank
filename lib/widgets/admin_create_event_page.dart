import 'package:flutter/material.dart';
import 'package:runrank/services/event_service.dart';
import 'package:runrank/services/notification_service.dart';

class AdminCreateEventPage extends StatefulWidget {
  const AdminCreateEventPage({super.key});

  @override
  State<AdminCreateEventPage> createState() => _AdminCreateEventPageState();
}

class _AdminCreateEventPageState extends State<AdminCreateEventPage> {
  final _formKey = GlobalKey<FormState>();

  String _eventType = 'training'; // 'training', 'event', 'race', 'handicap'

  // Shared fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _leadHostDirectorController =
      TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _venueAddressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Training-specific
  int _trainingNumber = 1; // 1 or 2

  // Race-specific
  String _selectedRaceName = 'Holt 10K';

  // Handicap-specific
  String _selectedHandicapDistance = '5 km';

  // Relay-specific
  String _relayTeam = 'A';

  // Dates & times
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _marshalCallDate; // race + handicap only

  // For future map support
  double? mapLat;
  double? mapLng;

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

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
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

    // Build a display title appropriately for type
    String title;
    String? raceName;
    String? handicapDistance;
    int? trainingNumber;
    String? relayTeam;

    if (_eventType == 'training') {
      trainingNumber = _trainingNumber;
      final custom = _titleController.text.trim();
      title = custom.isEmpty
          ? 'Training $trainingNumber'
          : 'Training $trainingNumber — $custom';
    } else if (_eventType == 'event') {
      title = _titleController.text.trim();
    } else if (_eventType == 'race') {
      raceName = _selectedRaceName;
      title = 'Race: $raceName';
    } else if (_eventType == 'handicap') {
      handicapDistance = _selectedHandicapDistance;
      title = 'Handicap ($handicapDistance)';
    } else if (_eventType == 'relay') {
      relayTeam = _relayTeam;
      title = 'RNR Relay – Team $relayTeam';
    } else {
      title = _titleController.text.trim().isEmpty
          ? 'Club Activity'
          : _titleController.text.trim();
    }

    try {
      // 🔵 Call EventService to create event in Supabase
      final eventId = await EventService.createEvent(
        eventType: _eventType,
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

      // ➜ eventId is returned by EventService.createEvent()

      // ------------------------------------------------------
      // 🔔 SEND NOTIFICATION TO ALL USERS
      // ------------------------------------------------------

      final friendlyDate =
          '${fullDateTime.day.toString().padLeft(2, '0')}/${fullDateTime.month.toString().padLeft(2, '0')}';
      final friendlyTime =
          '${fullDateTime.hour.toString().padLeft(2, '0')}:${fullDateTime.minute.toString().padLeft(2, '0')}';

      final message =
          '$title on $friendlyDate at $friendlyTime'
          '${venue.isNotEmpty ? ' · $venue' : ''}';

      await NotificationService.notifyAllUsers(
        title: 'New $_eventType created',
        body: message,
        eventId: eventId,
      );

      // ------------------------------------------------------

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved $_eventType: $title')));

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save event: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Club Activity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event type selector
              DropdownButtonFormField<String>(
                value: _eventType,
                items: const [
                  DropdownMenuItem(value: 'training', child: Text('Training')),
                  DropdownMenuItem(value: 'event', child: Text('Event')),
                  DropdownMenuItem(value: 'race', child: Text('Race')),
                  DropdownMenuItem(value: 'handicap', child: Text('Handicap')),
                  DropdownMenuItem(value: 'relay', child: Text('RNR Relay')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _eventType = v);
                },
                decoration: const InputDecoration(labelText: 'Activity type'),
              ),

              const SizedBox(height: 16),

              // Dynamic title / specific fields
              if (_eventType == 'training') ...[
                Row(
                  children: [
                    const Text(
                      'Training number:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _trainingNumber,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Training 1')),
                        DropdownMenuItem(value: 2, child: Text('Training 2')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _trainingNumber = v);
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
              ] else if (_eventType == 'event') ...[
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event name',
                    hintText: 'e.g. Night of Celebrations',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ] else if (_eventType == 'race') ...[
                DropdownButtonFormField<String>(
                  value: _selectedRaceName,
                  items: _raceNames
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedRaceName = v);
                  },
                  decoration: const InputDecoration(labelText: 'Race name'),
                ),
              ] else if (_eventType == 'handicap') ...[
                DropdownButtonFormField<String>(
                  value: _selectedHandicapDistance,
                  items: _handicapDistances
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedHandicapDistance = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Handicap distance',
                  ),
                ),
              ] else if (_eventType == 'relay') ...[
                DropdownButtonFormField<String>(
                  value: _relayTeam,
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('Team A')),
                    DropdownMenuItem(value: 'B', child: Text('Team B')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _relayTeam = v);
                  },
                  decoration: const InputDecoration(labelText: 'Relay Team'),
                ),
              ],

              const SizedBox(height: 16),

              // Date & Time
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

              // Lead / Host / Run Director(s)
              TextFormField(
                controller: _leadHostDirectorController,
                decoration: InputDecoration(
                  labelText: _eventType == 'race' || _eventType == 'handicap'
                      ? 'Run Director(s)'
                      : _eventType == 'training'
                      ? 'Training lead name'
                      : 'Host',
                  hintText: _eventType == 'race' || _eventType == 'handicap'
                      ? 'e.g. John Smith, Sarah Jones'
                      : null,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // Venue
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(
                  labelText: 'Venue',
                  hintText: 'e.g. Cromer Lawn Tennis & Racket Sports',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _venueAddressController,
                decoration: const InputDecoration(
                  labelText: 'Venue address',
                  hintText: 'e.g. Norwich Rd, Cromer',
                ),
              ),

              const SizedBox(height: 16),

              // Marshal call date (race & handicap only)
              if (_eventType == 'race' || _eventType == 'handicap') ...[
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
              ],

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  hintText: 'Describe the activity...',
                ),
              ),

              const SizedBox(height: 24),

              // Save button
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
