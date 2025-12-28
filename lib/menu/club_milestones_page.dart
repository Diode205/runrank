import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:runrank/services/club_milestones_service.dart';
import 'package:runrank/services/user_service.dart';

class ClubMilestonesPage extends StatefulWidget {
  const ClubMilestonesPage({super.key});

  @override
  State<ClubMilestonesPage> createState() => _ClubMilestonesPageState();
}

class _ClubMilestonesPageState extends State<ClubMilestonesPage> {
  final _service = ClubMilestonesService();
  List<ClubMilestone> _milestones = [];
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
    _milestones = await _service.getAllMilestones();
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
          'Club Milestones',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0055FF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Key moments and achievements that have shaped our club\'s journey over the years.',
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
                  if (_milestones.isEmpty)
                    _buildEmptyState()
                  else
                    ..._milestones
                        .asMap()
                        .entries
                        .map(
                          (entry) => _buildMilestone(
                            milestone: entry.value,
                            isLast: entry.key == _milestones.length - 1,
                          ),
                        )
                        .toList(),
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
          colors: [Color(0xFF0055FF), Color(0xFF00AAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Milestone',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            Icon(Icons.timeline, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No milestones yet',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestone({
    required ClubMilestone milestone,
    required bool isLast,
  }) {
    return InkWell(
      onLongPress: _isAdmin ? () => _showOptionsDialog(milestone) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0055FF), Color(0xFF00AAFF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0055FF).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIconData(milestone.icon),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: Colors.white.withOpacity(0.2),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.milestoneDate,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0055FF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    milestone.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    milestone.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'flag': Icons.flag,
      'people': Icons.people,
      'waves': Icons.waves,
      'emoji_events': Icons.emoji_events,
      'star': Icons.star,
      'celebration': Icons.celebration,
      'sports': Icons.sports,
      'group': Icons.group,
      'local_fire_department': Icons.local_fire_department,
      'emoji_people': Icons.emoji_people,
      'card_giftcard': Icons.card_giftcard,
      'volunteer_activism': Icons.volunteer_activism,
    };
    return iconMap[iconName] ?? Icons.emoji_events;
  }

  void _showAddDialog() {
    final dateController = TextEditingController();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedIcon = 'emoji_events';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D2E),
          title: const Text(
            'Add Milestone',
            style: TextStyle(color: Color(0xFF0055FF)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Date/Era (e.g., "1980s" or "2024")',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'Icon',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(color: Colors.white),
                  items:
                      [
                            'flag',
                            'people',
                            'waves',
                            'emoji_events',
                            'star',
                            'celebration',
                            'sports',
                            'group',
                            'local_fire_department',
                            'emoji_people',
                            'card_giftcard',
                            'volunteer_activism',
                          ]
                          .map(
                            (icon) => DropdownMenuItem(
                              value: icon,
                              child: Row(
                                children: [
                                  Icon(
                                    _getIconData(icon),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(icon),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedIcon = val);
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
                if (dateController.text.trim().isEmpty ||
                    titleController.text.trim().isEmpty ||
                    descController.text.trim().isEmpty) {
                  return;
                }

                final milestone = ClubMilestone(
                  id: '',
                  milestoneDate: dateController.text.trim(),
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  icon: selectedIcon,
                  displayOrder: _milestones.length + 1,
                );

                final success = await _service.addMilestone(milestone);
                if (success && mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0055FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsDialog(ClubMilestone milestone) {
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
              leading: const Icon(Icons.edit, color: Color(0xFF0055FF)),
              title: const Text(
                'Edit Milestone',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(milestone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text(
                'Delete Milestone',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(milestone);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ClubMilestone milestone) {
    final dateController = TextEditingController(text: milestone.milestoneDate);
    final titleController = TextEditingController(text: milestone.title);
    final descController = TextEditingController(text: milestone.description);
    String selectedIcon = milestone.icon;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D2E),
          title: const Text(
            'Edit Milestone',
            style: TextStyle(color: Color(0xFF0055FF)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Date/Era',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'Icon',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(color: Colors.white),
                  items:
                      [
                            'flag',
                            'people',
                            'waves',
                            'emoji_events',
                            'star',
                            'celebration',
                            'sports',
                            'group',
                            'local_fire_department',
                            'emoji_people',
                            'card_giftcard',
                            'volunteer_activism',
                          ]
                          .map(
                            (icon) => DropdownMenuItem(
                              value: icon,
                              child: Row(
                                children: [
                                  Icon(
                                    _getIconData(icon),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(icon),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedIcon = val);
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
                if (dateController.text.trim().isEmpty ||
                    titleController.text.trim().isEmpty ||
                    descController.text.trim().isEmpty) {
                  return;
                }

                final updated = ClubMilestone(
                  id: milestone.id,
                  milestoneDate: dateController.text.trim(),
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  icon: selectedIcon,
                  displayOrder: milestone.displayOrder,
                );

                final success = await _service.updateMilestone(
                  milestone.id,
                  updated,
                );
                if (success && mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0055FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ClubMilestone milestone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Delete Milestone',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'Are you sure you want to delete "${milestone.title}"?',
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
              final success = await _service.deleteMilestone(milestone.id);
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
