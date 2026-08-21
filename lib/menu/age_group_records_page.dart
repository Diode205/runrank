import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:runrank/services/age_group_records_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/standards_data.dart';

class AgeGroupRecordsPage extends StatefulWidget {
  const AgeGroupRecordsPage({super.key});

  @override
  State<AgeGroupRecordsPage> createState() => _AgeGroupRecordsPageState();
}

class _AgeGroupRecordsPageState extends State<AgeGroupRecordsPage> {
  final _recordsService = AgeGroupRecordsService();

  bool _loading = true;
  bool _isAdmin = false;
  String? _clubName;
  // distance -> (age group band -> top 3 records)
  Map<String, Map<String, List<AgeGroupRecord>>> _recordsByDistance = {};
  String _currentGender = 'M';

  // Age-group records apply to all standard distances except Ultra.
  final _distances = const [
    '5K',
    '5M',
    '10K',
    '10M',
    'Half M',
    'Marathon',
    '20M',
  ];
  late final PageController _pageController;
  int _currentIndex = 0;

  bool get _isNrrClub {
    final club = _clubName?.toLowerCase() ?? '';
    return club == 'nrr' || club.contains('norwich road runners');
  }

  bool get _isYcrrClub {
    final club = _clubName?.trim().toLowerCase() ?? '';
    return club == 'ycrr' || club.contains('your club road runners');
  }

  Color get _primaryColor => _isNrrClub
      ? const Color(0xFFD32F2F)
      : _isYcrrClub
      ? const Color(0xFFFFD300)
      : const Color(0xFFF5C542);

  Color get _secondaryColor => _isNrrClub
      ? Colors.white
      : _isYcrrClub
      ? const Color(0xFF16803A)
      : const Color(0xFF0057B7);

  Color get _cardBorderColor => _isNrrClub ? _primaryColor : _secondaryColor;

  List<String> get _ageGroupOrder => ageGroupOrderForClub(_clubName);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    _clubName = await _recordsService.getClubName();
    _isAdmin = await UserService.isAdmin();
    final defaultGender = await _recordsService.getDefaultGenderFilter();
    _currentGender = (defaultGender == 'F') ? 'F' : 'M';

    await _loadRecordsForGender(_currentGender);
    setState(() => _loading = false);
  }

  Future<void> _loadRecordsForGender(String gender) async {
    setState(() => _loading = true);

    final results = await Future.wait(
      _distances.map(
        (distance) => _recordsService.getTopRecordsByAgeGroup(
          distance,
          genderFilter: gender,
        ),
      ),
    );

    _recordsByDistance = {
      for (var i = 0; i < _distances.length; i++) _distances[i]: results[i],
    };
    _currentGender = gender;

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Age-Group Records — ${_distances[_currentIndex]}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _primaryColor))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top 3 performances in each age category, across every distance — a runner\'s age at the time of the race determines their category.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGenderToggle(),
                  const SizedBox(height: 16),
                  if (_isAdmin) _buildAdminButtons(),
                  if (_isAdmin) const SizedBox(height: 16),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _distances.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (context, i) {
                        final distance = _distances[i];
                        final byGroup =
                            _recordsByDistance[distance] ?? const {};
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDistanceHeader(distance),
                              const SizedBox(height: 16),
                              for (final band in _ageGroupOrder) ...[
                                _buildAgeGroupSection(
                                  distance,
                                  band,
                                  byGroup[band] ?? const [],
                                ),
                                const SizedBox(height: 16),
                              ],
                              const SizedBox(height: 8),
                              _buildPagerControls(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGenderToggle() {
    final isMale = _currentGender == 'M';
    final currentLabel = isMale
        ? "Showing Men's Age-Group Records"
        : "Showing Women's Age-Group Records";
    final buttonLabel = isMale ? "View Women's Records" : "View Men's Records";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            currentLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton(
            onPressed: () {
              final nextGender = isMale ? 'F' : 'M';
              _loadRecordsForGender(nextGender);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: _primaryColor),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Admin Controls',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddRecordDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Record'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: _primaryColor.computeLuminance() > 0.6
                  ? Colors.black
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PagerButton(
          icon: Icons.chevron_left,
          color: _primaryColor,
          enabled: _currentIndex > 0,
          onTap: () => _pageController.previousPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${_currentIndex + 1}/${_distances.length}',
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(width: 16),
        _PagerButton(
          icon: Icons.chevron_right,
          color: _primaryColor,
          enabled: _currentIndex < _distances.length - 1,
          onTap: () => _pageController.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        ),
      ],
    );
  }

  Widget _buildDistanceHeader(String distance) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          distance,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAgeGroupSection(
    String distance,
    String band,
    List<AgeGroupRecord> records,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBorderColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayAgeGroupLabel(band),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Text(
              'No records yet for this age group',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            )
          else
            ...records
                .asMap()
                .entries
                .map((e) => _buildRecordRow(e.value, e.key + 1))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildRecordRow(AgeGroupRecord record, int position) {
    final positionColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];
    final positionColor = positionColors[position - 1];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onLongPress: _isAdmin && _canAdminManageRecord(record)
              ? () => _showRecordOptions(record)
              : null,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: positionColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: positionColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$position',
                    style: TextStyle(
                      color: positionColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.runnerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${record.raceName} • ${_formatDate(record.raceDate)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                record.formattedTime,
                style: TextStyle(
                  color: positionColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canAdminManageRecord(AgeGroupRecord record) {
    return !record.id.startsWith('live-');
  }

  void _showRecordOptions(AgeGroupRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.edit, color: _primaryColor),
              title: const Text(
                'Edit Record',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditRecordDialog(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text(
                'Delete Record',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteRecord(record);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRecordDialog() => _showRecordDialog();

  void _showEditRecordDialog(AgeGroupRecord record) =>
      _showRecordDialog(existing: record);

  void _showRecordDialog({AgeGroupRecord? existing}) {
    final runnerNameController = TextEditingController(
      text: existing?.runnerName ?? '',
    );
    final raceNameController = TextEditingController(
      text: existing?.raceName ?? '',
    );
    final ageController = TextEditingController(
      text: existing?.ageAtRace?.toString() ?? '',
    );
    final timeController = TextEditingController(
      text: existing != null ? _formatSecondsToTime(existing.timeSeconds) : '',
    );
    DateTime selectedDate = existing?.raceDate ?? DateTime.now();
    String selectedDistance = existing?.distance ?? _distances[_currentIndex];
    String selectedGender = existing?.gender ?? _currentGender;
    String selectedBand = existing?.ageGroup ?? _ageGroupOrder.first;
    bool isHistorical = existing?.isHistorical ?? false;
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D2E),
          title: Text(
            isEdit ? 'Edit Age-Group Record' : 'Add Age-Group Record',
            style: const TextStyle(color: Color(0xFFFFD700)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedDistance,
                  decoration: const InputDecoration(
                    labelText: 'Distance',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(color: Colors.white),
                  items: _distances
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedDistance = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text("Men's")),
                    DropdownMenuItem(value: 'F', child: Text("Women's")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedGender = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedBand,
                  decoration: const InputDecoration(
                    labelText: 'Age Group',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(color: Colors.white),
                  items: _ageGroupOrder
                      .map(
                        (band) => DropdownMenuItem(
                          value: band,
                          child: Text(displayAgeGroupLabel(band)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedBand = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Age at race (optional)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: runnerNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Runner Name',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Time (e.g., 18:30 or 1:23:45)',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'MM:SS or H:MM:SS',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: raceNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Race Name',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Race Date',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  subtitle: Text(
                    _formatDate(selectedDate),
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFFFFD700),
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(1980),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Historical Record',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'For old records by non-members',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  value: isHistorical,
                  activeColor: const Color(0xFFFFD700),
                  onChanged: (val) {
                    setDialogState(() => isHistorical = val ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final timeSeconds = _parseTimeToSeconds(
                  timeController.text.trim(),
                );
                if (timeSeconds == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid time format')),
                  );
                  return;
                }

                final record = AgeGroupRecord(
                  id: existing?.id ?? '',
                  distance: selectedDistance,
                  ageGroup: selectedBand,
                  ageAtRace: int.tryParse(ageController.text.trim()),
                  timeSeconds: timeSeconds,
                  runnerName: runnerNameController.text.trim(),
                  userId: existing?.userId,
                  gender: selectedGender,
                  raceName: raceNameController.text.trim(),
                  raceDate: selectedDate,
                  isHistorical: isHistorical,
                );

                final success = isEdit
                    ? await _recordsService.updateRecord(existing.id, record)
                    : await _recordsService.addRecord(record);

                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Record updated successfully'
                            : 'Record added successfully',
                      ),
                    ),
                  );
                  _loadRecordsForGender(_currentGender);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Failed to update record'
                            : 'Failed to add record',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
              ),
              child: Text(isEdit ? 'Update' : 'Add Record'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRecord(AgeGroupRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Delete Record',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'Are you sure you want to delete ${record.runnerName}\'s record of ${record.formattedTime} for ${record.distance}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _recordsService.deleteRecord(record.id);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Record deleted')));
                _loadRecordsForGender(_currentGender);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  int? _parseTimeToSeconds(String timeStr) {
    final parts = timeStr.split(':');
    try {
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return minutes * 60 + seconds;
      } else if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return hours * 3600 + minutes * 60 + seconds;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  String _formatSecondsToTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _PagerButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _PagerButton({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 36,
            color: Colors.white.withOpacity(enabled ? 0.08 : 0.03),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onTap : null,
                child: SizedBox(
                  width: 44,
                  height: 36,
                  child: Icon(icon, color: enabled ? color : Colors.white24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
