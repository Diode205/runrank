import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:runrank/auth/login_screen.dart';
import 'package:runrank/menu/charity_page.dart';
import 'package:runrank/menu/club_history_page.dart';
import 'package:runrank/menu/kit_merchandise_page.dart';
import 'package:runrank/menu/membership_page.dart';
import 'package:runrank/menu/races_eaccl_page_clean.dart';
import 'package:runrank/menu/rnr_ekiden_eaccl_page.dart';
import 'package:runrank/menu/admin_team_page.dart';
import 'package:runrank/menu/policies_forms_notices_page.dart';
import 'package:runrank/menu/app_settings_page.dart';
import 'package:runrank/menu/athletics_portal_power10_page.dart';
import 'package:runrank/menu/runners_banquet_page.dart';
import 'package:runrank/menu/malcolm_ball_award_page.dart';
import 'package:runrank/menu/runners_of_the_year_page.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/main.dart' show routeObserver;

const List<String> _emergencyRelations = [
  'Spouse',
  'Partner',
  'Parent',
  'Friend',
  'Child',
  'Kin',
  'Carer',
];

class _QuickEditResult {
  const _QuickEditResult({
    required this.fullName,
    required this.email,
    required this.membershipType,
    required this.memberSince,
    required this.emergencyContactName,
    required this.emergencyContactNumber,
    required this.emergencyContactRelation,
    required this.emergencyDetailsConsent,
  });

  final String? fullName;
  final String? email;
  final String? membershipType;
  final DateTime? memberSince;
  final String? emergencyContactName;
  final String? emergencyContactNumber;
  final String? emergencyContactRelation;
  final bool emergencyDetailsConsent;
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with RouteAware {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;
  bool _loggingOut = false;
  bool _isAdmin = false;
  String? _fullName;
  String? _email;
  String? _ukaNumber;
  String? _club;
  String? _avatarUrl;
  DateTime? _memberSince;
  String? _membershipType;
  String? _emergencyContactName;
  String? _emergencyContactNumber;
  String? _emergencyContactRelation;
  bool _emergencyDetailsConsent = false;
  ModalRoute<void>? _subscribedRoute;

  bool get _isNrrClub {
    final club = (_club ?? '').trim().toLowerCase();
    return club == 'nrr' || club.contains('norwich road runners');
  }

  bool get _isYcrrClub {
    final club = (_club ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return club == 'ycrr' || club.contains('yourclubroadrunners');
  }

  Color get _clubPrimaryColor => _club == null
      ? const Color(0xFF3A3A3A)
      : _isNrrClub
      ? const Color(0xFFD32F2F)
      : _isYcrrClub
      ? const Color(0xFFFFD300)
      : const Color(0xFFFFD300);

  Color get _clubSecondaryColor => _club == null
      ? Colors.white70
      : _isNrrClub
      ? Colors.white
      : _isYcrrClub
      ? const Color(0xFF16803A)
      : const Color(0xFF0057B7);

  Color get _quickEditBackgroundColor => _club == null
      ? const Color(0xFF111111)
      : _isNrrClub
      ? const Color(0xFF140708)
      : _isYcrrClub
      ? const Color(0xFF10140F)
      : const Color(0xFF0F111A);

  Color get _quickEditFieldFillColor => _club == null
      ? const Color(0xFF1A1A1A)
      : _isNrrClub
      ? const Color(0xFF211012)
      : _isYcrrClub
      ? const Color(0xFF162319)
      : const Color(0xFF161B26);

  List<Color> get _quickEditHeaderGradient => _club == null
      ? const [Color(0xFF2A2A2A), Color(0xFF101010)]
      : _isNrrClub
      ? const [Color(0xFF7B1620), Color(0xFF200608)]
      : _isYcrrClub
      ? const [Color(0xFF16803A), Color(0xFFFFD300)]
      : const [Color(0xFF0057B7), Color(0xFFFFD300)];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _subscribedRoute) {
      routeObserver.unsubscribe(this);
      _subscribedRoute = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _subscribedRoute = null;
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadProfile();
  }

  // Quick edit bottom sheet
  Future<void> _showQuickEditSheet() async {
    final result = await showModalBottomSheet<_QuickEditResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: _quickEditBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QuickEditSheet(
        fullName: _fullName,
        email: _email,
        membershipType: _membershipType,
        memberSince: _memberSince,
        emergencyContactName: _emergencyContactName,
        emergencyContactNumber: _emergencyContactNumber,
        emergencyContactRelation: _emergencyContactRelation,
        emergencyDetailsConsent: _emergencyDetailsConsent,
        backgroundColor: _quickEditBackgroundColor,
        fieldFillColor: _quickEditFieldFillColor,
        headerGradient: _quickEditHeaderGradient,
        primaryColor: _clubPrimaryColor,
        secondaryColor: _clubSecondaryColor,
        isNrrClub: _isNrrClub,
        formatDate: _formatDate,
      ),
    );

    if (result == null || !mounted) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final updateData = <String, dynamic>{
      'full_name': result.fullName,
      'email': result.email,
      'membership_type': result.membershipType,
      'emergency_contact_name': result.emergencyContactName,
      'emergency_contact_number': result.emergencyContactNumber,
      'emergency_contact_relation': result.emergencyContactRelation,
      'emergency_details_consent': result.emergencyDetailsConsent,
    };
    if (result.memberSince != null) {
      updateData['member_since'] = result.memberSince!.toIso8601String();
    }

    try {
      await _supabase
          .from('user_profiles')
          .update(updateData)
          .eq('id', user.id);

      if (result.fullName != null && result.fullName!.isNotEmpty) {
        await _syncProfileNameReferences(
          userId: user.id,
          newName: result.fullName!,
        );
      }

      if (!mounted) return;
      setState(() {
        _fullName = result.fullName;
        _email = result.email;
        _membershipType = result.membershipType;
        _memberSince = result.memberSince;
        _emergencyContactName = result.emergencyContactName;
        _emergencyContactNumber = result.emergencyContactNumber;
        _emergencyContactRelation = result.emergencyContactRelation;
        _emergencyDetailsConsent = result.emergencyDetailsConsent;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _clubPrimaryColor,
          content: Text(
            'Profile updated',
            style: TextStyle(color: _isNrrClub ? Colors.white : Colors.black),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed\n$e')));
    }
  }

  Future<void> _syncProfileNameReferences({
    required String userId,
    required String newName,
  }) async {
    try {
      await _supabase
          .from('club_posts')
          .update({'author_name': newName})
          .eq('author_id', userId);
    } catch (e) {
      debugPrint('Unable to sync club post author name: $e');
    }

    try {
      await _supabase
          .from('club_records')
          .update({'runner_name': newName})
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Unable to sync club record runner name: $e');
    }
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
            'full_name, email, uka_number, club, avatar_url, member_since, membership_type, is_admin, admin_since, created_at, emergency_contact_name, emergency_contact_number, emergency_contact_relation, emergency_details_consent',
          )
          .eq('id', user.id)
          .maybeSingle();
      final isAdmin = await UserService.isAdmin();
      final memberSinceRaw = profile?['member_since'];
      final createdAtRaw = profile?['created_at'];
      DateTime? parsedMemberSince = memberSinceRaw is String
          ? DateTime.tryParse(memberSinceRaw)
          : memberSinceRaw is DateTime
          ? memberSinceRaw
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
      setState(() {
        _fullName = profile?['full_name'] as String?;
        _email = profile?['email'] as String?;
        _ukaNumber = profile?['uka_number'] as String?;
        _club = profile?['club'] as String?;
        UserService.cacheClubName(_club);
        _avatarUrl = profile?['avatar_url'] as String?;
        _memberSince = parsedMemberSince;
        _membershipType = profile?['membership_type'] as String?;
        _emergencyContactName = profile?['emergency_contact_name'] as String?;
        _emergencyContactNumber =
            profile?['emergency_contact_number'] as String?;
        _emergencyContactRelation =
            profile?['emergency_contact_relation'] as String?;
        _emergencyDetailsConsent =
            profile?['emergency_details_consent'] == true;
        _isAdmin = isAdmin;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loggingOut) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Membership color not needed in the header container anymore
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white70),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppSettingsPage()),
            );
          },
        ),
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
              extent: _headerExtent(context),
              child: Container(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    children: [_profileHeader(), const SizedBox(height: 4)],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 6),
                _infoFieldBox(),
                const SizedBox(height: 12),
                _membershipButton(),
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
                  title: (_isNrrClub || _isYcrrClub)
                      ? 'Signature Races'
                      : 'Signature & Handicap Races',
                  subtitle: 'Management & Participations',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RacesEacclPage()),
                    );
                  },
                ),
                // Handicap Series is integrated into Signature & Handicap page
                _menuTile(
                  icon: Icons.shopping_bag,
                  title: 'Kit & Merchandise',
                  subtitle: 'Order Vests, Shorts, Hoodies & More',
                  onTap: () {
                    if (_isYcrrClub) {
                      _showDemoUnavailableMessage('Kit & Merchandise');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KitMerchandisePage(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.emoji_events,
                  title: 'Inspirational Running Awards',
                  subtitle: 'Nominate, Vote, and Comments',
                  onTap: () {
                    if (_isYcrrClub) {
                      _showDemoUnavailableMessage(
                        'Inspirational Running Awards',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MalcolmBallAwardPage(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.workspace_premium,
                  title: 'Runners Of The Year',
                  subtitle: "The Winners' List",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RunnersOfTheYearPage(),
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
                  icon: Icons.volunteer_activism,
                  title: 'Charity of the Year',
                  subtitle: 'Community Support and Donations',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CharityPage()),
                    );
                  },
                ),
                _menuSectionDivider(),
                _menuTile(
                  icon: Icons.groups,
                  title: 'Relay & Cross Country Teams',
                  subtitle: 'RNR, Ekiden, and EACCL Teams',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RnrEkidenEacclPage(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.public,
                  title: 'Athletics Portal & Power of 10',
                  subtitle: 'England Athletics login and search',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AthleticsPortalPower10Page(),
                      ),
                    );
                  },
                ),
                _menuSectionDivider(),
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
                _menuTile(
                  icon: Icons.description,
                  title: 'Club Governance',
                  subtitle: 'Club policies and key mandates',
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
                    '© 2025 RunRank · All Rights Reserved',
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
    final colorScheme = Theme.of(context).colorScheme;
    final primary = _brandPrimary(colorScheme);

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
        return primary;
    }
  }

  Widget _profileHeader() {
    final name = _fullName?.isNotEmpty == true ? _fullName! : 'Set your name';
    final email = _email?.isNotEmpty == true ? _email! : 'Add an email';
    final memberSince = _memberSince != null
        ? 'Member Since ${_formatDate(_memberSince!)}'
        : 'Member since not set';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _photoCard(),
        const SizedBox(width: 12),
        Expanded(
          child: _detailsCard(
            name: name,
            email: email,
            memberSince: memberSince,
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
                      membershipColor.withValues(alpha: 0.18),
                      membershipColor.withValues(alpha: 0.08),
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
    final colorScheme = Theme.of(context).colorScheme;
    final primary = _brandPrimary(colorScheme);
    final accent = _brandAccent(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent,
            primary.withValues(alpha: 0.35),
            const Color(0xFF0F111A),
          ],
          stops: const [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary, width: 1.1),
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
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = _brandPrimary(colorScheme);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('UKA Membership Nos.', _ukaNumber ?? 'Not set'),
          const Divider(color: Colors.white12),
          _infoRow('Club', _club ?? 'Not set'),
          const Divider(color: Colors.white12),
          _infoRow('ICE contact', _emergencyContactSummary()),
        ],
      ),
    );
  }

  String _emergencyContactSummary() {
    if (!_emergencyDetailsConsent ||
        _emergencyContactName == null ||
        _emergencyContactName!.trim().isEmpty ||
        _emergencyContactNumber == null ||
        _emergencyContactNumber!.trim().isEmpty) {
      return 'Not shared';
    }

    final relation = _emergencyContactRelation?.trim();
    final relationText = relation == null || relation.isEmpty
        ? ''
        : ' ($relation)';
    return '${_emergencyContactName!}$relationText';
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
    final colorScheme = Theme.of(context).colorScheme;
    final outlineColor = _brandAccent(colorScheme);
    final contentColor = outlineColor;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: outlineColor),
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
        icon: Icon(Icons.desktop_windows, color: contentColor),
        label: Text(
          'Membership & Renewal',
          style: TextStyle(color: contentColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  void _showDemoUnavailableMessage(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName can be connected for a live club build.'),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = _brandAccent(colorScheme);

    return Card(
      color: const Color(0xFF0F111A),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: ListTile(
        leading: Icon(icon, size: 30, color: borderColor),
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

  Widget _menuSectionDivider() {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _brandAccent(colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(
            3,
            (index) => Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.75),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
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
        onPressed: _loggingOut
            ? null
            : () async {
                final navigator = Navigator.of(context);
                setState(() => _loggingOut = true);
                UserService.clearCachedClubName();

                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );

                await AuthService.logout();
              },
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Log Out',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  // Brand-aware helpers: if both primary and accent from the
  // club configuration are very light (near white), fall back
  // to the NNBR-style yellow/blue so borders and gradients stay
  // visible on dark backgrounds.

  Color _brandPrimary(ColorScheme colorScheme) {
    final pLum = colorScheme.primary.computeLuminance();
    final sLum = colorScheme.secondary.computeLuminance();
    if (pLum > 0.8 && sLum > 0.8) {
      return const Color(0xFFF5C542); // NNBR yellow
    }
    return colorScheme.primary;
  }

  Color _brandAccent(ColorScheme colorScheme) {
    final pLum = colorScheme.primary.computeLuminance();
    final sLum = colorScheme.secondary.computeLuminance();
    if (pLum > 0.8 && sLum > 0.8) {
      return const Color(0xFF0057B7); // NNBR blue
    }
    return colorScheme.secondary;
  }
}

class _QuickEditSheet extends StatefulWidget {
  const _QuickEditSheet({
    required this.fullName,
    required this.email,
    required this.membershipType,
    required this.memberSince,
    required this.emergencyContactName,
    required this.emergencyContactNumber,
    required this.emergencyContactRelation,
    required this.emergencyDetailsConsent,
    required this.backgroundColor,
    required this.fieldFillColor,
    required this.headerGradient,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isNrrClub,
    required this.formatDate,
  });

  final String? fullName;
  final String? email;
  final String? membershipType;
  final DateTime? memberSince;
  final String? emergencyContactName;
  final String? emergencyContactNumber;
  final String? emergencyContactRelation;
  final bool emergencyDetailsConsent;
  final Color backgroundColor;
  final Color fieldFillColor;
  final List<Color> headerGradient;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isNrrClub;
  final String Function(DateTime date) formatDate;

  @override
  State<_QuickEditSheet> createState() => _QuickEditSheetState();
}

class _QuickEditSheetState extends State<_QuickEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyNumberController;
  String? _selectedMembershipType;
  DateTime? _selectedMemberSince;
  String? _selectedEmergencyRelation;
  late bool _shareEmergencyDetails;
  String? _quickEditError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fullName ?? '');
    _emailController = TextEditingController(text: widget.email ?? '');
    _emergencyNameController = TextEditingController(
      text: widget.emergencyContactName ?? '',
    );
    _emergencyNumberController = TextEditingController(
      text: widget.emergencyContactNumber ?? '',
    );
    _selectedMembershipType = widget.membershipType;
    _selectedMemberSince = widget.memberSince;
    _selectedEmergencyRelation = widget.emergencyContactRelation;
    _shareEmergencyDetails = widget.emergencyDetailsConsent;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyNumberController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: widget.fieldFillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.secondaryColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.primaryColor),
      ),
    );
  }

  Future<void> _pickMemberSinceDate() async {
    final now = DateTime.now();
    final initial = _selectedMemberSince ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedMemberSince = picked);
  }

  void _submit() {
    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newEmergencyName = _emergencyNameController.text.trim();
    final newEmergencyNumber = _emergencyNumberController.text.trim();

    final hasAnyEmergencyInput =
        newEmergencyName.isNotEmpty ||
        newEmergencyNumber.isNotEmpty ||
        _selectedEmergencyRelation != null ||
        _shareEmergencyDetails;

    if (hasAnyEmergencyInput &&
        (newEmergencyName.isEmpty ||
            newEmergencyNumber.isEmpty ||
            _selectedEmergencyRelation == null)) {
      setState(() {
        _quickEditError =
            'Please complete the emergency contact name, number and relationship';
      });
      return;
    }

    Navigator.of(context).pop(
      _QuickEditResult(
        fullName: newName.isEmpty ? null : newName,
        email: newEmail.isEmpty ? null : newEmail,
        membershipType: _selectedMembershipType,
        memberSince: _selectedMemberSince,
        emergencyContactName: newEmergencyName.isEmpty
            ? null
            : newEmergencyName,
        emergencyContactNumber: newEmergencyNumber.isEmpty
            ? null
            : newEmergencyNumber,
        emergencyContactRelation: _selectedEmergencyRelation,
        emergencyDetailsConsent: _shareEmergencyDetails,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: mediaQuery.viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.9),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.headerGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Quick edit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.secondaryColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const Text(
                'Swipe down or tap close to dismiss.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Name / nickname'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              const Text(
                'Membership type',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedMembershipType,
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
                  setState(() => _selectedMembershipType = val);
                },
                decoration: _inputDecoration('Select membership'),
                dropdownColor: widget.backgroundColor,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'Member since',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _selectedMemberSince != null
                      ? widget.formatDate(_selectedMemberSince!)
                      : 'Select date',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: widget.secondaryColor),
                ),
                onPressed: _pickMemberSinceDate,
              ),
              const SizedBox(height: 18),
              const Text(
                'Emergency contact',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emergencyNameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('ICE contact name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emergencyNumberController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('ICE contact number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedEmergencyRelation,
                items: _emergencyRelations
                    .map(
                      (relation) => DropdownMenuItem<String>(
                        value: relation,
                        child: Text(relation),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedEmergencyRelation = value);
                },
                decoration: _inputDecoration('Relationship'),
                dropdownColor: widget.backgroundColor,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _shareEmergencyDetails,
                onChanged: (value) {
                  setState(() {
                    _shareEmergencyDetails = value ?? false;
                  });
                },
                title: const Text(
                  'Allow club emergency access to these details',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                subtitle: const Text(
                  'Used by club admins and members in an emergency during training or racing.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                activeColor: widget.primaryColor,
                checkColor: widget.isNrrClub ? Colors.white : Colors.black,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: widget.isNrrClub
                        ? Colors.white
                        : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
              if (_quickEditError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _quickEditError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
            ],
          ),
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

double _headerExtent(BuildContext context) {
  // Base required height to fit avatar + details comfortably
  const base = 168.0; // accounts for image, labels, and padding
  final scale = MediaQuery.textScalerOf(context).scale(1);
  // Allow a little extra for larger accessibility text sizes
  final extra = (scale > 1.0) ? (base * ((scale - 1.0).clamp(0.0, 0.2))) : 0.0;
  return base + extra;
}
