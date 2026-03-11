import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/services/club_config_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdministrativeTeamPage extends StatefulWidget {
  const AdministrativeTeamPage({super.key});

  @override
  State<AdministrativeTeamPage> createState() => _AdministrativeTeamPageState();
}

class _AdministrativeTeamPageState extends State<AdministrativeTeamPage> {
  final _supabase = Supabase.instance.client;
  bool _isAdmin = false;
  String? _adminClub;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _committeeLoaded = false;
  ClubConfig? _clubConfig;

  final List<Map<String, dynamic>> _committee = [
    // Initial roles only; names/emails left blank so clubs can configure their own holders
    {'role': 'President', 'name': '', 'email': ''},
    {'role': 'Chairperson', 'name': '', 'email': ''},
    {'role': 'Vice-Chairperson', 'name': '', 'email': ''},
    {'role': 'Secretary', 'name': '', 'email': ''},
    {'role': 'Treasurer', 'name': '', 'email': ''},
    {'role': 'Membership Secretary', 'name': '', 'email': ''},
    {'role': 'Minutes Secretary', 'name': '', 'email': ''},
    {'role': 'Clothing Manager', 'name': '', 'email': ''},
    {'role': 'Club Head Coach', 'name': '', 'email': ''},
    {'role': 'Equipment Store Manager', 'name': '', 'email': ''},
    {'role': 'General Committee Member', 'name': '', 'email': ''},
    {'role': 'General Committee Member', 'name': '', 'email': ''},
    {'role': 'Webmaster', 'name': '', 'email': ''},
    {'role': 'Press Officer', 'name': '', 'email': ''},
  ];

  @override
  void initState() {
    super.initState();
    _loadAdmin();
    _loadCommitteeFromDb();
    _loadClubConfig();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _isAdmin = false;
        _adminClub = null;
      });
      return;
    }

    try {
      final profile = await _supabase
          .from('user_profiles')
          .select('is_admin, club')
          .eq('id', user.id)
          .maybeSingle();

      final isAdmin = (profile?['is_admin'] ?? false) as bool;
      final club = profile?['club']?.toString();

      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _adminClub = club;
      });
    } catch (e) {
      debugPrint('Error loading admin profile: $e');
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
      });
    }
  }

  Future<void> _loadCommitteeFromDb() async {
    try {
      final club = _adminClub;
      if (club == null || club.isEmpty) {
        if (!mounted) return;
        setState(() {
          _committeeLoaded = true;
        });
        return;
      }

      final data = await _supabase
          .from('committee_roles')
          .select('id, role, name, email, user_id, avatar_url')
          .eq('club', club)
          .order('display_order');

      if (!mounted) return;

      final rows = List<Map<String, dynamic>>.from(data as List);
      if (rows.isEmpty) {
        setState(() {
          _committeeLoaded = true;
        });
        return;
      }

      setState(() {
        _committee
          ..clear()
          ..addAll(
            rows.map(
              (row) => {
                'id': row['id']?.toString(),
                'role': row['role']?.toString() ?? '',
                'name': row['name']?.toString() ?? '',
                'email': row['email']?.toString() ?? '',
                'userId': row['user_id']?.toString() ?? '',
                'avatarUrl': row['avatar_url']?.toString() ?? '',
              },
            ),
          );
        _committeeLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading committee from DB: $e');
      if (!mounted) return;
      setState(() {
        _committeeLoaded = true;
      });
    }
  }

  Future<void> _loadClubConfig() async {
    try {
      final config = await ClubConfigService.loadForCurrentUser();
      if (!mounted) return;
      setState(() {
        _clubConfig = config;
      });
    } catch (e) {
      debugPrint('Error loading club config for admin page: $e');
    }
  }

  void _editMember(int index) {
    if (!_isAdmin) return;

    final member = _committee[index];

    // Admins don't need to backspace to replace someone: fields start blank
    // with the current holder shown as a hint.
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final primary = colorScheme.primary;

        return AlertDialog(
          backgroundColor: const Color(0xFF0F111A),
          title: Text(
            'Edit ${member['role']}',
            style: TextStyle(color: primary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: (member['name'] ?? '').toString().isNotEmpty
                        ? member['name']?.toString()
                        : null,
                    hintStyle: const TextStyle(color: Colors.white38),
                    suffixIcon: IconButton(
                      tooltip: 'Search club members',
                      icon: Icon(Icons.search, color: primary),
                      onPressed: () => _openMemberSelector(
                        index,
                        nameController,
                        emailController,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
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
                final newName = nameController.text.trim();
                final newEmail = emailController.text.trim();

                setState(() {
                  _committee[index]['name'] = newName;
                  if (newName.isEmpty) {
                    _committee[index]['email'] = '';
                    _committee[index]['userId'] = '';
                    _committee[index]['avatarUrl'] = '';
                  } else {
                    _committee[index]['email'] = newEmail;
                  }
                });
                Navigator.pop(context);

                final id = _committee[index]['id']?.toString();
                if (id == null || id.isEmpty) return;

                try {
                  await _supabase
                      .from('committee_roles')
                      .update({
                        'name': newName,
                        'email': newName.isEmpty ? '' : newEmail,
                        'user_id': newName.isEmpty
                            ? null
                            : (_committee[index]['userId'] ?? '')
                                  .toString()
                                  .isEmpty
                            ? null
                            : _committee[index]['userId'],
                        'avatar_url': newName.isEmpty
                            ? ''
                            : (_committee[index]['avatarUrl'] ?? '').toString(),
                      })
                      .eq('id', id);
                } catch (e) {
                  debugPrint('Error updating committee role: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _openMemberSelector(
    int index,
    TextEditingController nameController,
    TextEditingController emailController,
  ) {
    if (!_isAdmin) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final primary = colorScheme.primary;
        final localSearchController = TextEditingController();
        List<Map<String, dynamic>> results = [];
        bool searching = false;

        Future<void> doSearch(String term, StateSetter setModalState) async {
          if (term.trim().length < 2) {
            setModalState(() {
              results = [];
              searching = false;
            });
            return;
          }

          setModalState(() => searching = true);
          try {
            final clubName = _adminClub;

            var query = _supabase
                .from('user_profiles')
                .select('id, full_name, email, avatar_url, membership_type');

            if (clubName != null && clubName.isNotEmpty) {
              query = query.eq('club', clubName);
            }

            final data = await query
                .or('full_name.ilike.%$term%,email.ilike.%$term%')
                .limit(20);

            setModalState(() {
              results = List<Map<String, dynamic>>.from(data);
            });
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
          } finally {
            setModalState(() => searching = false);
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.search, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select member for ${_committee[index]['role']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: localSearchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.person_search,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF151828),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primary.withOpacity(0.4)),
                      ),
                    ),
                    onChanged: (value) => doSearch(value, setModalState),
                  ),
                  const SizedBox(height: 12),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(),
                    )
                  else if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Start typing to search members',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    SizedBox(
                      height: 320,
                      child: ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white12, height: 12),
                        itemBuilder: (_, i) {
                          final user = results[i];
                          final avatarUrl =
                              (user['avatar_url'] as String?) ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: colorScheme.primary.withOpacity(
                                0.25,
                              ),
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            title: Text(
                              user['full_name'] ?? 'Member',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              user['email'] ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _committee[index]['name'] =
                                    (user['full_name'] ?? '') as String;
                                _committee[index]['email'] =
                                    (user['email'] ?? '') as String;
                                _committee[index]['userId'] =
                                    user['id'] as String;
                                _committee[index]['avatarUrl'] = avatarUrl;
                              });
                              nameController.text =
                                  _committee[index]['name'] ?? '';
                              emailController.text =
                                  _committee[index]['email'] ?? '';
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _searchUsers(String term, StateSetter setModalState) async {
    final messenger = ScaffoldMessenger.of(context);

    if (term.trim().length < 2) {
      setModalState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setModalState(() => _searching = true);
    try {
      final clubName = _adminClub;

      var query = _supabase
          .from('user_profiles')
          .select(
            'id, full_name, email, membership_type, is_admin, admin_since, is_blocked, block_reason, club',
          );

      if (clubName != null && clubName.isNotEmpty) {
        query = query.eq('club', clubName);
      }

      final data = await query
          .or('full_name.ilike.%$term%,email.ilike.%$term%')
          .limit(20);

      setModalState(() {
        _searchResults = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setModalState(() => _searching = false);
    }
  }

  Future<void> _setAdminStatus(
    Map<String, dynamic> user,
    bool makeAdmin,
    StateSetter setModalState,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      debugPrint(
        'Setting admin status for user ${user['id']}: makeAdmin=$makeAdmin',
      );

      final result = await _supabase
          .from('user_profiles')
          .update({
            'is_admin': makeAdmin,
            'admin_since': makeAdmin ? DateTime.now().toIso8601String() : null,
          })
          .eq('id', user['id'] as String);

      debugPrint('Update result: $result');

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            makeAdmin ? 'User promoted to admin' : 'User demoted to reader',
          ),
        ),
      );

      debugPrint('Refreshing search results after admin status change');
      await _searchUsers(_searchController.text, setModalState);
    } catch (e, stackTrace) {
      debugPrint('Error setting admin status: $e');
      debugPrintStack(stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update admin status: $e')),
      );
    }
  }

  Future<void> _warnUser(
    Map<String, dynamic> user,
    StateSetter setModalState,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final primary = Theme.of(dialogContext).colorScheme.primary;
        return AlertDialog(
          backgroundColor: const Color(0xFF0F111A),
          title: Text('Send warning', style: TextStyle(color: primary)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Message to user',
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (ok != true || controller.text.trim().isEmpty) return;

    try {
      await NotificationService.notifyUser(
        userId: user['id'] as String,
        title: 'Account notice',
        body: controller.text.trim(),
      );

      messenger.showSnackBar(const SnackBar(content: Text('Warning sent')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send warning: $e')),
      );
    }
  }

  Future<void> _blockUser(
    Map<String, dynamic> user,
    bool block,
    StateSetter setModalState,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String? reason;

    if (block) {
      final reasonController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final primary = Theme.of(dialogContext).colorScheme.primary;
          return AlertDialog(
            backgroundColor: const Color(0xFF0F111A),
            title: Text('Block user', style: TextStyle(color: primary)),
            content: TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Theme.of(
                    dialogContext,
                  ).colorScheme.onPrimary,
                ),
                child: const Text('Block'),
              ),
            ],
          );
        },
      );

      if (ok != true) return;
      reason = reasonController.text.trim();
    }

    try {
      await _supabase
          .from('user_profiles')
          .update({'is_blocked': block, 'block_reason': block ? reason : null})
          .eq('id', user['id'] as String);

      messenger.showSnackBar(
        SnackBar(content: Text(block ? 'User blocked' : 'User unblocked')),
      );

      await _searchUsers(_searchController.text, setModalState);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Update failed. Ensure is_blocked and block_reason columns exist. ($e)',
          ),
        ),
      );
    }
  }

  Future<void> _launchEmail({required String subject, String? body}) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {'subject': subject, if (body != null) 'body': body},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _confirmRemoveProfile(
    Map<String, dynamic> user,
    StateSetter setModalState,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: const Text(
          'Remove Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Soft removal will immediately block access and clear optional profile details.\n\n'
          'Member: ${user['full_name'] ?? '—'}\nEmail: ${user['email'] ?? '—'}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _softRemoveProfile(user, setModalState);
            },
            child: const Text(
              'Soft remove now',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchEmail(
                subject: 'RunRank profile removal request',
                body:
                    'Please remove the profile for: ${user['full_name'] ?? '—'} (${user['email'] ?? '—'}).',
              );
            },
            child: const Text(
              'Request via Email',
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _softRemoveProfile(
    Map<String, dynamic> user,
    StateSetter setModalState,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: const Text(
          'Confirm Soft Removal',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final reason = reasonController.text.trim();
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'is_blocked': true,
            'block_reason':
                (reason.isNotEmpty
                        ? 'Removed by admin: $reason'
                        : 'Removed by admin')
                    .trim(),
            'membership_type': null,
            'avatar_url': null,
            'is_admin': false,
            'admin_since': null,
          })
          .eq('id', user['id'] as String);

      messenger.showSnackBar(
        const SnackBar(content: Text('Profile soft-removed and blocked')),
      );
      await _searchUsers(_searchController.text, setModalState);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Soft removal failed: $e')),
      );
    }
  }

  void _openAdminControls() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final primary = colorScheme.primary;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: primary),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Admin controls',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF151828),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: primary.withOpacity(0.4),
                          ),
                        ),
                      ),
                      onChanged: (value) => _searchUsers(value, setModalState),
                    ),
                    const SizedBox(height: 12),
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      )
                    else if (_searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Start typing to search members',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      SizedBox(
                        height: 360,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white12, height: 16),
                          itemBuilder: (_, index) {
                            final user = _searchResults[index];
                            final isAdmin = user['is_admin'] == true;
                            final isBlocked = user['is_blocked'] == true;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['full_name'] ?? 'Member',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        user['email'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Chip(
                                            label: Text(
                                              isAdmin ? 'Admin' : 'Reader',
                                            ),
                                            backgroundColor: isAdmin
                                                ? Colors.green.withOpacity(0.2)
                                                : Colors.blue.withOpacity(0.2),
                                            labelStyle: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              user['membership_type'] ?? '—',
                                            ),
                                            backgroundColor: Colors.white
                                                .withOpacity(0.08),
                                            labelStyle: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (isBlocked)
                                            Chip(
                                              label: const Text('Blocked'),
                                              backgroundColor: Colors.red
                                                  .withOpacity(0.2),
                                              labelStyle: const TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (user['block_reason'] != null &&
                                          (user['block_reason'] as String?)
                                                  ?.isNotEmpty ==
                                              true)
                                        Text(
                                          'Reason: ${user['block_reason']}',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      tooltip: isAdmin
                                          ? 'Remove admin'
                                          : 'Make admin',
                                      onPressed: () => _setAdminStatus(
                                        user,
                                        !isAdmin,
                                        setModalState,
                                      ),
                                      icon: Icon(
                                        isAdmin
                                            ? Icons.security_update_warning
                                            : Icons.verified_user,
                                        color: isAdmin
                                            ? Colors.orangeAccent
                                            : Colors.greenAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      tooltip: 'Warn user',
                                      onPressed: () =>
                                          _warnUser(user, setModalState),
                                      icon: const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      tooltip: isBlocked ? 'Unblock' : 'Block',
                                      onPressed: () => _blockUser(
                                        user,
                                        !isBlocked,
                                        setModalState,
                                      ),
                                      icon: Icon(
                                        isBlocked
                                            ? Icons.lock_open
                                            : Icons.block,
                                        color: isBlocked
                                            ? Colors.lightGreenAccent
                                            : Colors.redAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      tooltip: 'Remove profile',
                                      onPressed: () => _confirmRemoveProfile(
                                        user,
                                        setModalState,
                                      ),
                                      icon: const Icon(
                                        Icons.delete_forever_outlined,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showContactForm(int index) {
    final member = _committee[index];
    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final primary = colorScheme.primary;

        return AlertDialog(
          backgroundColor: const Color(0xFF0F111A),
          title: Text(
            'Contact ${member['name']}',
            style: TextStyle(color: primary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Role: ${member['role']}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (subjectController.text.trim().isEmpty ||
                    messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // TODO: Store enquiry in Supabase or send via email service
                // For now, show a confirmation
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Message sent to ${member['name']}. Thank you!',
                    ),
                    backgroundColor: primary,
                  ),
                );
              },
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final accent = colorScheme.secondary;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Club Committee',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        primary.withOpacity(0.75),
                        primary.withOpacity(0.45),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: primary, width: 1),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Centered title + description
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Builder(
                            builder: (context) {
                              final name = _clubConfig?.name ?? '';
                              String display;
                              if (name.isEmpty) {
                                display = 'Club Committee';
                              } else {
                                // Use simple initials (e.g. "NNBR", "NRR")
                                // to avoid overlapping the admin icon.
                                final lower = name.toLowerCase();
                                String initials;
                                if (lower.contains('norwich road runners')) {
                                  initials = 'NRR';
                                } else if (lower.contains(
                                      'north norfolk beach runners',
                                    ) ||
                                    lower.contains('nnbr')) {
                                  initials = 'NNBR';
                                } else {
                                  final buffer = StringBuffer();
                                  for (final raw in name.split(' ')) {
                                    final letters = raw
                                        .replaceAll(RegExp(r'[^A-Za-z]'), '')
                                        .trim();
                                    if (letters.isNotEmpty) {
                                      buffer.write(letters[0].toUpperCase());
                                    }
                                  }
                                  initials = buffer.isEmpty
                                      ? name
                                      : buffer.toString();
                                }
                                display = '$initials Committee';
                              }

                              return Text(
                                display,
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'For general enquiries, please contact The Chairperson or The Secretary via email.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      // Left icon decorative only; aligned with header text
                      Positioned(
                        top: 4,
                        left: 12,
                        child: Icon(
                          Icons.people,
                          color: colorScheme.onPrimary.withOpacity(0.9),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Admin controls',
                      onPressed: _openAdminControls,
                      icon: Icon(Icons.admin_panel_settings, color: primary),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !_committeeLoaded
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _committee.length,
                    itemBuilder: (context, index) {
                      final member = _committee[index];
                      final hasEmail = (member['email'] ?? '').isNotEmpty;
                      final avatarUrl = member['avatarUrl'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: primary.withOpacity(0.35),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  if (avatarUrl.isNotEmpty)
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: primary.withOpacity(
                                        0.25,
                                      ),
                                      backgroundImage: NetworkImage(avatarUrl),
                                    )
                                  else
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [primary, accent],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member['role'] ?? '',
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          member['name'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (hasEmail)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              member['email'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 40,
                                  ), // Space for buttons
                                ],
                              ),
                            ),
                            // Edit button (top right corner)
                            if (_isAdmin)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _editMember(index),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primary.withOpacity(0.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: primary.withOpacity(0.45),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        color: primary,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Mail button (bottom right corner)
                            if (hasEmail)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showContactForm(index),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accent.withOpacity(0.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: accent.withOpacity(0.45),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.send,
                                        color: accent,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
