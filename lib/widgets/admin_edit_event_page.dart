import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/models/club_event.dart';

class AdminEditEventPage extends StatefulWidget {
  final ClubEvent event;

  const AdminEditEventPage({super.key, required this.event});

  @override
  State<AdminEditEventPage> createState() => _AdminEditEventPageState();
}

class _AdminEditEventPageState extends State<AdminEditEventPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController titleCtrl;
  late TextEditingController hostCtrl;
  late TextEditingController venueCtrl;
  late TextEditingController venueAddressCtrl;
  late TextEditingController descriptionCtrl;

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  DateTime? marshalCallDate; // for race/handicap

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    titleCtrl = TextEditingController(text: e.title ?? '');
    hostCtrl = TextEditingController(text: e.hostOrDirector);
    venueCtrl = TextEditingController(text: e.venue);
    venueAddressCtrl = TextEditingController(text: e.venueAddress);
    descriptionCtrl = TextEditingController(text: e.description);
    selectedDate = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
    selectedTime = TimeOfDay(hour: e.dateTime.hour, minute: e.dateTime.minute);
    marshalCallDate = e.marshalCallDate;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    hostCtrl.dispose();
    venueCtrl.dispose();
    venueAddressCtrl.dispose();
    descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  Future<void> _pickMarshalDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: marshalCallDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => marshalCallDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    final timeString =
        "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}";

    final payload = {
      'title': titleCtrl.text.trim().isEmpty
          ? widget.event.title
          : titleCtrl.text.trim(),
      'date': selectedDate!.toIso8601String().split('T').first,
      'time': timeString,
      'host_or_director': hostCtrl.text.trim(),
      'venue': venueCtrl.text.trim(),
      'venue_address': venueAddressCtrl.text.trim(),
      'description': descriptionCtrl.text.trim(),
      'marshal_call_date':
          (widget.event.eventType == 'race' ||
              widget.event.eventType == 'handicap_series')
          ? marshalCallDate?.toIso8601String().split('T').first
          : null,
    };

    setState(() => _saving = true);
    try {
      await supabase
          .from('club_events')
          .update(payload)
          .eq('id', widget.event.id);

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event updated')));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type: ${e.eventType}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        selectedDate == null
                            ? 'Pick date'
                            : selectedDate!.toIso8601String().split('T').first,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        selectedTime == null
                            ? 'Pick time'
                            : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: hostCtrl,
                decoration: const InputDecoration(labelText: 'Host / Director'),
              ),
              TextFormField(
                controller: venueCtrl,
                decoration: const InputDecoration(labelText: 'Venue'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: venueAddressCtrl,
                decoration: const InputDecoration(labelText: 'Venue Address'),
              ),
              TextFormField(
                controller: descriptionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              if (e.eventType == 'race' ||
                  e.eventType == 'handicap_series') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickMarshalDate,
                  icon: const Icon(Icons.flag),
                  label: Text(
                    marshalCallDate == null
                        ? 'Pick marshal call date'
                        : marshalCallDate!.toIso8601String().split('T').first,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
