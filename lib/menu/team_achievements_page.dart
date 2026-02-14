import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:runrank/services/team_achievements_service.dart';
import 'package:runrank/services/user_service.dart';

class TeamAchievementsPage extends StatefulWidget {
  const TeamAchievementsPage({super.key});

  @override
  State<TeamAchievementsPage> createState() => _TeamAchievementsPageState();
}

class _TeamAchievementsPageState extends State<TeamAchievementsPage> {
  final _service = TeamAchievementsService();
  List<TeamAchievement> _achievements = [];
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _isAdmin = await UserService.isAdmin();
    _achievements = await _service.getAllAchievements();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Team Achievements',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Our team achievements celebrate the collective successes of North Norfolk Beach Runners across various competitions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isAdmin) ...[
                    _buildAdminButton(),
                    const SizedBox(height: 24),
                  ],
                  if (_achievements.isEmpty)
                    _buildEmptyState()
                  else
                    ..._achievements.map(_buildAchievementCard).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildAdminButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Add Achievement',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No team achievements yet',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(TeamAchievement achievement) {
    final awardConfig = _getAwardConfig(achievement.award);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            awardConfig['color']!.withOpacity(0.15),
            Colors.black.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: awardConfig['color']!.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: awardConfig['color']!.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onLongPress: _isAdmin ? () => _showOptionsDialog(achievement) : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Award medal icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: awardConfig['color']!.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: awardConfig['color']!,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        awardConfig['icon'] as IconData,
                        color: awardConfig['color'],
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            achievement.award.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: awardConfig['color'],
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            achievement.eventName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        achievement.teams,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white60,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(achievement.achievementDate),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
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

  Map<String, dynamic> _getAwardConfig(String award) {
    switch (award) {
      case 'Gold':
        return {'color': const Color(0xFFFFD700), 'icon': Icons.emoji_events};
      case 'Silver':
        return {'color': const Color(0xFFC0C0C0), 'icon': Icons.emoji_events};
      case 'Bronze':
        return {'color': const Color(0xFFCD7F32), 'icon': Icons.emoji_events};
      case 'Champion':
        return {'color': const Color(0xFF0055FF), 'icon': Icons.military_tech};
      default:
        return {'color': Colors.white, 'icon': Icons.emoji_events};
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

  void _showAddDialog() {
    final eventController = TextEditingController();
    final teamsController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedAward = 'Gold';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D2E),
          title: const Text(
            'Add Team Achievement',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: eventController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Event Name',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedAward,
                  decoration: const InputDecoration(
                    labelText: 'Award',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(color: Colors.white),
                  items: ['Gold', 'Silver', 'Bronze', 'Champion']
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedAward = val);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Date',
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
                const SizedBox(height: 16),
                TextField(
                  controller: teamsController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Teams / Participants',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'e.g., John Doe, Jane Smith, ...',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
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
                if (eventController.text.trim().isEmpty ||
                    teamsController.text.trim().isEmpty) {
                  return;
                }

                final achievement = TeamAchievement(
                  id: '',
                  achievementDate: selectedDate,
                  eventName: eventController.text.trim(),
                  award: selectedAward,
                  teams: teamsController.text.trim(),
                );

                final success = await _service.addAchievement(achievement);
                if (success && mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsDialog(TeamAchievement achievement) {
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
                'Edit Achievement',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(achievement);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text(
                'Delete Achievement',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(achievement);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(TeamAchievement achievement) {
    final eventController = TextEditingController(text: achievement.eventName);
    final teamsController = TextEditingController(text: achievement.teams);
    DateTime selectedDate = achievement.achievementDate;
    String selectedAward = achievement.award;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D2E),
          title: const Text(
            'Edit Achievement',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: eventController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Event Name',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedAward,
                  decoration: const InputDecoration(
                    labelText: 'Award',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(color: Colors.white),
                  items: ['Gold', 'Silver', 'Bronze', 'Champion']
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedAward = val);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Date',
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
                const SizedBox(height: 16),
                TextField(
                  controller: teamsController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Teams / Participants',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
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
                if (eventController.text.trim().isEmpty ||
                    teamsController.text.trim().isEmpty) {
                  return;
                }

                final updated = TeamAchievement(
                  id: achievement.id,
                  achievementDate: selectedDate,
                  eventName: eventController.text.trim(),
                  award: selectedAward,
                  teams: teamsController.text.trim(),
                );

                final success = await _service.updateAchievement(
                  achievement.id,
                  updated,
                );
                if (success && mounted) {
                  Navigator.pop(context);
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

  void _confirmDelete(TeamAchievement achievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Delete Achievement',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'Are you sure you want to delete this achievement for ${achievement.eventName}?',
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
              final success = await _service.deleteAchievement(achievement.id);
              if (success && mounted) {
                Navigator.pop(context);
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
}
