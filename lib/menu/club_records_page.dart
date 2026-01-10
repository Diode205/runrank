import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:runrank/services/club_records_service.dart';
import 'package:runrank/services/user_service.dart';

class ClubRecordsPage extends StatefulWidget {
  final String? initialDistance;
  const ClubRecordsPage({super.key, this.initialDistance});

  @override
  State<ClubRecordsPage> createState() => _ClubRecordsPageState();
}

class _ClubRecordsPageState extends State<ClubRecordsPage> {
  final _recordsService = ClubRecordsService();

  bool _loading = true;
  bool _isAdmin = false;
  Map<String, List<ClubRecord>> _recordsByDistance = {};
  final _distances = const ['5K', '5M', '10K', '10M', 'Half M', 'Marathon'];
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Set initial page from optional distance
    if (widget.initialDistance != null) {
      final i = _distances.indexOf(widget.initialDistance!);
      _currentIndex = i >= 0 ? i : 0;
    }
    _pageController = PageController(initialPage: _currentIndex);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    _isAdmin = await UserService.isAdmin();
    _recordsByDistance = await _recordsService.getAllTopRecords(
      limitPerDistance: 10,
    );

    setState(() => _loading = false);
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Club Records — ${_distances[_currentIndex]}',
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
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Our club records represent the pinnacle of achievement by our members across various distances.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                  ),
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
                        final allRecords =
                            _recordsByDistance[distance] ?? const [];
                        final topThree = allRecords.take(3).toList();
                        final nextSeven = allRecords.skip(3).take(7).toList();
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDistanceHeader(distance),
                              const SizedBox(height: 16),
                              if (allRecords.isEmpty)
                                _buildEmptyState()
                              else ...[
                                // Top 3 prominent
                                ...topThree
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) =>
                                          _buildRecordCard(e.value, e.key + 1),
                                    )
                                    .toList(),
                                // Next 7 smaller list
                                if (nextSeven.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  _buildNextSevenSection(nextSeven),
                                ],
                              ],
                              const SizedBox(height: 24),
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

  Widget _buildAdminButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: Color(0xFFFFD700),
                size: 20,
              ),
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
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _syncRecordsFromRaceResults,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sync from Race Results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0055FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncRecordsFromRaceResults() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1A1D2E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0055FF)),
            SizedBox(height: 16),
            Text(
              'Syncing records from race results...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );

    try {
      await _recordsService.syncFromRaceResults();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Records synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload the page
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing records: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPagerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PagerButton(
          icon: Icons.chevron_left,
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
            color: const Color(0xFFFFD700),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          distance,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: const Center(
        child: Text(
          'No records yet for this distance',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildRecordCard(ClubRecord record, int position) {
    final positionColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
      Colors.white54,
      Colors.white38,
    ];

    final positionColor = position <= positionColors.length
        ? positionColors[position - 1]
        : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: position == 1
              ? const Color(0xFFFFD700).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: _isAdmin ? () => _showRecordOptions(record) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Position badge
                Container(
                  width: 36,
                  height: 36,
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
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Record details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            record.runnerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (record.isHistorical) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Historical',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.raceName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(record.raceDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      record.formattedTime,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: positionColor,
                      ),
                    ),
                    if (position == 1)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 12,
                            color: Color(0xFFFFD700),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Club Record',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecordOptions(ClubRecord record) {
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
              leading: const Icon(Icons.edit, color: Color(0xFFFFD700)),
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

  void _showAddRecordDialog() {
    final runnerNameController = TextEditingController();
    final raceNameController = TextEditingController();
    final timeController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedDistance = '5K';
    bool isHistorical = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D2E),
          title: const Text(
            'Add Club Record',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDistance,
                  decoration: const InputDecoration(
                    labelText: 'Distance',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(color: Colors.white),
                  items: ['5K', '5M', '10K', '10M', 'Half M', 'Marathon']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedDistance = val);
                    }
                  },
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

                final record = ClubRecord(
                  id: '',
                  distance: selectedDistance,
                  timeSeconds: timeSeconds,
                  runnerName: runnerNameController.text.trim(),
                  userId: null,
                  raceName: raceNameController.text.trim(),
                  raceDate: selectedDate,
                  isHistorical: isHistorical,
                );

                final success = await _recordsService.addRecord(record);
                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Record added successfully')),
                  );
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
              ),
              child: const Text('Add Record'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRecordDialog(ClubRecord record) {
    final runnerNameController = TextEditingController(text: record.runnerName);
    final raceNameController = TextEditingController(text: record.raceName);
    final timeController = TextEditingController(
      text: _formatSecondsToTime(record.timeSeconds),
    );
    DateTime selectedDate = record.raceDate;
    String selectedDistance = record.distance;
    bool isHistorical = record.isHistorical;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D2E),
          title: const Text(
            'Edit Club Record',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDistance,
                  decoration: const InputDecoration(
                    labelText: 'Distance',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(color: Colors.white),
                  items: ['5K', '5M', '10K', '10M', 'Half M', 'Marathon']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedDistance = val);
                    }
                  },
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

                final updatedRecord = ClubRecord(
                  id: record.id,
                  distance: selectedDistance,
                  timeSeconds: timeSeconds,
                  runnerName: runnerNameController.text.trim(),
                  userId: record.userId,
                  raceName: raceNameController.text.trim(),
                  raceDate: selectedDate,
                  isHistorical: isHistorical,
                );

                final success = await _recordsService.updateRecord(
                  record.id,
                  updatedRecord,
                );
                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Record updated successfully'),
                    ),
                  );
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRecord(ClubRecord record) {
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
                _loadData();
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
        // MM:SS
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return minutes * 60 + seconds;
      } else if (parts.length == 3) {
        // H:MM:SS
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

  Widget _buildNextSevenSection(List<ClubRecord> records) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'More Top Times',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0055FF),
            ),
          ),
          const SizedBox(height: 12),
          ...records.asMap().entries.map((entry) {
            final position = entry.key + 4; // 4th position onwards
            final record = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$position',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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
                    style: const TextStyle(
                      color: Color(0xFF0055FF),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PagerButton({
    required this.icon,
    required this.enabled,
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
                  child: Icon(
                    icon,
                    color: enabled ? const Color(0xFFFFD700) : Colors.white24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
