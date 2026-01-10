import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:runrank/admin/admin_charity_page.dart';
import 'package:runrank/auth/login_screen.dart';
import 'package:runrank/menu/club_history_page.dart';
import 'package:runrank/menu/kit_merchandise_page.dart';
import 'package:runrank/menu/membership_page.dart';
import 'package:runrank/menu/races_eaccl_page.dart';
import 'package:runrank/menu/admin_team_page.dart';
import 'package:runrank/menu/policies_forms_notices_page.dart';
import 'package:runrank/menu/runners_banquet_page.dart';
import 'package:runrank/menu/malcolm_ball_award_page.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/main.dart' show routeObserver;

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with RouteAware {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _isAdmin = false;
  final ImagePicker _picker = ImagePicker();

  String? _fullName;
  String? _email;
  String? _ukaNumber;
  String? _club;
  String? _avatarUrl;
  DateTime? _memberSince;
  DateTime? _adminSince;
  String? _membershipType;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadProfile();
  }

  // Quick edit bottom sheet
  Future<void> _showQuickEditSheet() async {
    final nameController = TextEditingController(text: _fullName ?? '');
    final emailController = TextEditingController(text: _email ?? '');
    final ukaController = TextEditingController(text: _ukaNumber ?? '');
    String? selectedMembershipType = _membershipType;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Quick edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Name / nickname'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ukaController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('UKA number'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Membership type',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedMembershipType,
                    items: const [
                      DropdownMenuItem(
                        value: '1st Claim',
                        child: Text('1st Claim'),
                      ),
                      DropdownMenuItem(
                        value: '2nd Claim',
                        child: Text('2nd Claim'),
                      ),
                      DropdownMenuItem(value: 'Social', child: Text('Social')),
                      DropdownMenuItem(
                        value: 'Full-Time Education',
                        child: Text('Full-Time Education'),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() => selectedMembershipType = val);
                    },
                    decoration: _inputDecoration('Select membership'),
                    dropdownColor: const Color(0xFF0F111A),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5C542),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final user = _supabase.auth.currentUser;
                        if (user == null) return;
                        final newName = nameController.text.trim();
                        final newEmail = emailController.text.trim();
                        final newUka = ukaController.text.trim();
                        try {
                          await _supabase
                              .from('user_profiles')
                              .update({
                                'full_name': newName.isEmpty ? null : newName,
                                'email': newEmail.isEmpty ? null : newEmail,
                                'uka_number': newUka.isEmpty ? null : newUka,
                                'membership_type': selectedMembershipType,
                              })
                              .eq('id', user.id);
                          setState(() {
                            _fullName = newName.isEmpty ? null : newName;
                            _email = newEmail.isEmpty ? null : newEmail;
                            _ukaNumber = newUka.isEmpty ? null : newUka;
                            _membershipType = selectedMembershipType;
                          });
                          if (!mounted) return;
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF1F3A93),
                              content: Text(
                                'Profile updated',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(
                                'Update failed\n$e',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nameController.dispose();
    emailController.dispose();
    ukaController.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF161B26),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1F3A93)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF5C542)),
      ),
    );
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = await _supabase
          .from('user_profiles')
          .select(
            'full_name, email, uka_number, club, avatar_url, member_since, membership_type, is_admin, admin_since, created_at',
          )
          .eq('id', user.id)
          .maybeSingle();
      final isAdmin = await UserService.isAdmin();
      final memberSinceRaw = profile?['member_since'];
      final adminSinceRaw = profile?['admin_since'];
      final createdAtRaw = profile?['created_at'];
      DateTime? parsedMemberSince = memberSinceRaw is String
          ? DateTime.tryParse(memberSinceRaw)
          : memberSinceRaw is DateTime
          ? memberSinceRaw
          : null;
      DateTime? parsedAdminSince = adminSinceRaw is String
          ? DateTime.tryParse(adminSinceRaw)
          : adminSinceRaw is DateTime
          ? adminSinceRaw
          : null;
      final parsedCreatedAt = createdAtRaw is String
          ? DateTime.tryParse(createdAtRaw)
          : createdAtRaw is DateTime
          ? createdAtRaw
          : null;
      if (parsedMemberSince == null && parsedCreatedAt != null) {
        try {
          await _supabase
              .from('user_profiles')
              .update({'member_since': parsedCreatedAt.toIso8601String()})
              .eq('id', user.id);
          parsedMemberSince = parsedCreatedAt;
        } catch (_) {}
      }
      if (isAdmin && parsedAdminSince == null) {
        try {
          final now = DateTime.now();
          await _supabase
              .from('user_profiles')
              .update({'admin_since': now.toIso8601String()})
              .eq('id', user.id);
          parsedAdminSince = now;
        } catch (_) {}
      }
      setState(() {
        _fullName = profile?['full_name'] as String?;
        _email = profile?['email'] as String?;
        _ukaNumber = profile?['uka_number'] as String?;
        _club = profile?['club'] as String?;
        _avatarUrl = profile?['avatar_url'] as String?;
        _memberSince = parsedMemberSince;
        _adminSince = parsedAdminSince;
        _membershipType = profile?['membership_type'] as String?;
        _isAdmin = isAdmin;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Membership color not needed in the header container anymore
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit profile',
            onPressed: _showQuickEditSheet,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _FixedHeaderDelegate(
              extent: 320,
              child: Container(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _profileHeader(),
                      const SizedBox(height: 16),
                      _infoFieldBox(),
                      const SizedBox(height: 12),
                      _membershipButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _menuTile(
                  icon: Icons.history_edu,
                  title: 'Club History',
                  subtitle: 'Records & Milestones',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ClubHistoryPage(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.flag,
                  title: 'Club Races & EACCL',
                  subtitle: 'History, Directing & Participation',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RacesEacclPage()),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.shopping_bag,
                  title: 'Kit & Merchandise',
                  subtitle: 'Order Vests, Shorts, Hoodies & More',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KitMerchandisePage(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.people_alt,
                  title: 'Administrative Team',
                  subtitle: 'Management Committee & Contacts',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdministrativeTeamPage(),
                      ),
                    );
                  },
                ),
                if (_isAdmin)
                  _menuTile(
                    icon: Icons.volunteer_activism,
                    title: 'Charity of the Year',
                    subtitle: 'Community Support and Donations',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminCharityEditorPage(),
                        ),
                      );
                    },
                  ),
                _menuTile(
                  icon: Icons.celebration,
                  title: 'Runners Banquette',
                  subtitle: 'Party Pass & Food Orders',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RunnersBanquetPage(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.emoji_events,
                  title: 'The Malcolm Ball Inspirational Running Award 2026',
                  subtitle: 'The Nominations, Votes, Reactions & Comments',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MalcolmBallAwardPage(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.description,
                  title: 'Policies, Forms, and Notices',
                  subtitle: 'Club policies, waivers, and key updates',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PoliciesFormsNoticesPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _logoutButton(),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    '© 2025 RunRank · All rights reserved',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMembershipColor(String? membershipType) {
    switch (membershipType) {
      case '1st Claim':
        return const Color(0xFFFFD700);
      case '2nd Claim':
        return const Color(0xFF0055FF);
      case 'Social':
        return Colors.grey;
      case 'Full-Time Education':
        return const Color(0xFF2E8B57);
      default:
        return const Color(0xFFF5C542);
    }
  }

  Widget _profileHeader() {
    final name = _fullName?.isNotEmpty == true ? _fullName! : 'Set your name';
    final email = _email?.isNotEmpty == true ? _email! : 'Add an email';
    final memberSince = _memberSince != null
        ? 'Member Since ${_formatMonthYear(_memberSince!)}'
        : 'Member since not set';
    final adminSince = _adminSince != null
        ? 'Admin Since ${_formatMonthYear(_adminSince!)}'
        : 'Admin since not set';
    final sinceLabel = _isAdmin ? adminSince : memberSince;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _photoCard(),
        const SizedBox(width: 12),
        Expanded(
          child: _detailsCard(
            name: name,
            email: email,
            memberSince: sinceLabel,
          ),
        ),
      ],
    );
  }

  Widget _photoCard() {
    final membershipColor = _getMembershipColor(_membershipType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _changeAvatar,
              child: Container(
                width: 110,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      membershipColor.withOpacity(0.18),
                      membershipColor.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: membershipColor, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.white10,
                      child: _avatarUrl != null
                          ? Image.network(
                              _avatarUrl!,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (context, error, stack) =>
                                  const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.white54,
                                    ),
                                  ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white70,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isAdmin)
              const Positioned(
                top: 2,
                right: 2,
                child: Text(
                  '🛡️',
                  style: TextStyle(
                    fontSize: 22,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            if (_avatarUrl != null)
              Positioned(
                bottom: 6,
                right: 6,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _removeAvatar,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.6),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap to change',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _detailsCard({
    required String name,
    required String email,
    required String memberSince,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F3A93),
            const Color(0xFFF5C542).withValues(alpha: 0.35),
            const Color(0xFF0F111A),
          ],
          stops: const [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5C542), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _chip(memberSince),
        ],
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (picked == null) return;
      final file = File(picked.path);
      if (!await file.exists()) throw Exception('Selected file does not exist');
      final path = '${user.id}/avatar.jpg';
      await _supabase.storage
          .from('avatars')
          .upload(
            path,
            file,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      await _supabase
          .from('user_profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);
      final publicUrlWithTs =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      setState(() => _avatarUrl = publicUrlWithTs);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update photo\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }
    try {
      final path = '${user.id}/avatar.jpg';
      await _supabase.storage.from('avatars').remove([path]);
      await _supabase
          .from('user_profiles')
          .update({'avatar_url': null})
          .eq('id', user.id);
      if (!mounted) return;
      setState(() => _avatarUrl = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo removed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove photo\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x33F5C542),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF5C542)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _infoFieldBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5C542), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('UKA Membership Nos.', _ukaNumber ?? 'Not set'),
          const Divider(color: Colors.white12),
          _infoRow('Club', _club ?? 'Not set'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _membershipButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white54),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MembershipPage()),
          );
        },
        icon: const Icon(Icons.desktop_windows, color: Colors.amber),
        label: const Text(
          'Membership & Renewal',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
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
    final m = months[date.month - 1];
    return '$m ${date.year}';
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF0F111A),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFF5C542), width: 1),
      ),
      child: ListTile(
        leading: Icon(icon, size: 30, color: const Color(0xFFF5C542)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 45, 2, 162),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          await AuthService.logout();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        },
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Log Out',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

class _FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double extent;
  _FixedHeaderDelegate({required this.child, required this.extent});
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _FixedHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}
