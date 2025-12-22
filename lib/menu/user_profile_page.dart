import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? _fullName;
  String? _email;
  String? _ukaNumber;
  String? _club;
  String? _membershipType;
  DateTime? _memberSince;
  DateTime? _dob;
  DateTime? _createdAt;
  String? _avatarUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Not logged in';
      });
      return;
    }

    try {
      final response = await _supabase
          .from('user_profiles')
          .select('''
            full_name,
            email,
            uka_number,
            club,
            membership_type,
            member_since,
            date_of_birth,
            avatar_url,
            created_at
          ''')
          .eq('id', user.id)
          .limit(1);

      if (response.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Profile not found';
        });
        return;
      }

      final row = response.first as Map<String, dynamic>;

      setState(() {
        _fullName = row['full_name'] as String?;
        _email = row['email'] as String?;
        _ukaNumber = row['uka_number'] as String?;
        _club = row['club'] as String?;
        _membershipType = row['membership_type'] as String?;
        _avatarUrl = row['avatar_url'] as String?;

        final dobStr = row['date_of_birth'] as String?;
        if (dobStr != null && dobStr.isNotEmpty) {
          _dob = DateTime.tryParse(dobStr);
        }

        final createdStr = row['created_at']?.toString();
        if (createdStr != null && createdStr.isNotEmpty) {
          _createdAt = DateTime.tryParse(createdStr);
        }

        final memberStr = row['member_since']?.toString();
        if (memberStr != null && memberStr.isNotEmpty) {
          _memberSince = DateTime.tryParse(memberStr);
        }

        _loading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error loading profile: $e');
      setState(() {
        _loading = false;
        _error = 'Failed to load profile';
      });
    }
  }

  String _initials() {
    final name = _fullName?.trim();
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts[1].isNotEmpty ? parts[1][0] : '');
  }

  String _memberSinceText() {
    final referenceDate = _memberSince ?? _createdAt;
    if (referenceDate == null) return 'Member';
    const months = [
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
    final m = months[referenceDate.month - 1];
    final y = referenceDate.year;
    return 'Member since $m $y';
  }

  String _formatDob() {
    if (_dob == null) return 'Not set';
    const months = [
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
    final m = months[_dob!.month - 1];
    return '${_dob!.day} $m ${_dob!.year}';
  }

  Future<void> _changeAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _saving = true);

      final file = File(picked.path);
      final path = 'avatars/${user.id}.jpg';

      // Upload to Supabase Storage (bucket: avatars)
      await _supabase.storage
          .from('avatars')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);

      // Save URL to profile
      await _supabase
          .from('user_profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      setState(() {
        _avatarUrl = publicUrl;
        _saving = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      // ignore: avoid_print
      print('Error updating avatar: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update photo')));
    }
  }

  Future<void> _showEditProfileSheet() async {
    final nameController = TextEditingController(text: _fullName ?? '');
    final ukaController = TextEditingController(text: _ukaNumber ?? '');
    String? selectedMembershipType = _membershipType;
    DateTime? selectedMemberSince = _memberSince;

    const membershipOptions = [
      '1st Claim',
      '2nd Claim',
      'Social',
      'Full-Time Education',
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Text(
                'Edit profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ukaController,
                decoration: const InputDecoration(labelText: 'UKA number'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Membership type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedMembershipType,
                items: membershipOptions
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedMembershipType = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Select membership',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Member since',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedMemberSince ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedMemberSince = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Member since date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    selectedMemberSince != null
                        ? '${selectedMemberSince!.day}/${selectedMemberSince!.month}/${selectedMemberSince!.year}'
                        : 'Select date',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final user = _supabase.auth.currentUser;
                    if (user == null) return;

                    final newName = nameController.text.trim();
                    final newUka = ukaController.text.trim();

                    try {
                      await _supabase
                          .from('user_profiles')
                          .update({
                            'full_name': newName,
                            'uka_number': newUka,
                            'membership_type': selectedMembershipType,
                            'member_since': selectedMemberSince
                                ?.toIso8601String(),
                          })
                          .eq('id', user.id);

                      setState(() {
                        _fullName = newName;
                        _ukaNumber = newUka;
                        _membershipType = selectedMembershipType;
                        _memberSince = selectedMemberSince;
                      });

                      if (!mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated')),
                      );
                    } catch (e) {
                      // ignore: avoid_print
                      print('Error updating profile: $e');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to update profile'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save changes'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHexAvatar() {
    final initials = _initials();

    return GestureDetector(
      onTap: _saving ? null : _changeAvatar,
      child: Column(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer blue hexagon border
                ClipPath(
                  clipper: _HexagonClipper(),
                  child: Container(
                    color: const Color(0xFF0057B7), // Blue border
                  ),
                ),
                // Inner dark hexagon with image / initials
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: ClipPath(
                    clipper: _HexagonClipper(),
                    child: Container(
                      color: Colors.grey.shade900,
                      child: _avatarUrl != null
                          ? Image.network(_avatarUrl!, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _saving ? 'Updating photo…' : 'Tap to change photo',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _fullName ?? 'Your Profile';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _loading ? null : _showEditProfileSheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildHexAvatar(),
                  const SizedBox(height: 16),

                  // Name + email
                  Text(
                    _fullName ?? 'Runner',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_email != null)
                    Text(
                      _email!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Member since chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD300).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD300),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _memberSinceText(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFFD300),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF0057B7),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0057B7).withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Membership type',
                          _membershipType ?? 'Not set',
                        ),
                        const Divider(color: Colors.white24),
                        _buildInfoRow(
                          'Member since',
                          _memberSince != null ? _memberSinceText() : 'Not set',
                        ),
                        const Divider(color: Colors.white24),
                        _buildInfoRow('UKA number', _ukaNumber ?? 'Not set'),
                        const Divider(color: Colors.white24),
                        _buildInfoRow('Club', _club ?? 'NNBR'),
                        const Divider(color: Colors.white24),
                        _buildInfoRow('Date of birth', _formatDob()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Placeholder action for renewal (for later integration)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Membership renewal coming soon.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.card_membership),
                      label: const Text('Membership & renewal'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Custom hexagon clipper for the avatar
class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    final double side = w / 2;
    final double triangleHeight = (h / 2);

    path.moveTo(w * 0.25, 0);
    path.lineTo(w * 0.75, 0);
    path.lineTo(w, triangleHeight);
    path.lineTo(w * 0.75, h);
    path.lineTo(w * 0.25, h);
    path.lineTo(0, triangleHeight);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_HexagonClipper oldClipper) => false;
}
