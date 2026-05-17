import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/services/club_config_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdministrativeTeamPage extends StatefulWidget {
  const AdministrativeTeamPage({super.key});

  @override
  State<AdministrativeTeamPage> createState() => _AdministrativeTeamPageState();
}

class _AdministrativeTeamPageState extends State<AdministrativeTeamPage> {
  static const List<String> _defaultCommitteeRoles = [
    'President',
    'Chairperson',
    'Vice-Chairperson',
    'Secretary',
    'Treasurer',
    'Membership Secretary',
    'Minutes Secretary',
    'Clothing Manager',
    'Club Head Coach',
    'Equipment Store Manager',
    'General Committee Member',
    'General Committee Member',
    'Webmaster',
    'Press Officer',
  ];

  static const List<String> _nrrCommitteeRoles = [
    'Chairperson',
    'Vice Chairperson',
    'Club Secretary',
    'Treasurer',
    'Membership Secretary',
    'Welfare Officer',
    'Health & Safety Officer',
    'New Members Officer',
    'Kit Secretary',
    'Junior Section Head',
    'Horford XC Race Director',
    'Road Racing Director',
    'Parkrun On Tour Lead',
    'Committee Member',
    'Committee Member',
    'Committee Member',
  ];

  final _supabase = Supabase.instance.client;
  bool _isAdmin = false;
  String? _adminClub;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _committeeLoaded = false;
  ClubConfig? _clubConfig;
  int _deletionRequestCount = 0;

  final List<Map<String, dynamic>> _committee = [];

  bool _isNrrClubName(String clubName) {
    final lower = clubName.trim().toLowerCase();
    return lower == 'nrr' || lower.contains('norwich road runners');
  }

  List<Map<String, dynamic>> _buildCommitteeTemplate(String clubName) {
    final roles = _isNrrClubName(clubName)
        ? _nrrCommitteeRoles
        : _defaultCommitteeRoles;
    return roles
        .map((role) => <String, dynamic>{'role': role, 'name': '', 'email': ''})
        .toList();
  }

  int? _resolveCommitteeIndexFromDisplayOrder(dynamic rawOrder) {
    if (rawOrder is! int) {
      return null;
    }

    final candidates = <int>[];
    if (rawOrder >= 0 && rawOrder < _committee.length) {
      candidates.add(rawOrder);
    }

    final oneBased = rawOrder - 1;
    if (oneBased >= 0 && oneBased < _committee.length) {
      candidates.add(oneBased);
    }

    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  void initState() {
    super.initState();
    _loadAdmin();
    _loadClubConfig();
    _loadDeletionRequestCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    final isAdmin = await UserService.isAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  Future<void> _loadClubConfig() async {
    try {
      final config = await ClubConfigService.loadForCurrentUser();
      final clubName = config.name;
      final isNrrClub = _isNrrClubName(clubName);

      _committee
        ..clear()
        ..addAll(_buildCommitteeTemplate(clubName));

      final data = await _supabase
          .from('committee_roles')
          .select(
            'id, role, display_order, name, email, user_id, avatar_url, club',
          )
          .eq('club', clubName)
          .order('display_order', ascending: true);

      final rows = (data as List).cast<dynamic>();
      // Map rows to slots primarily by role name for the default clubs.
      // For NRR, prefer display order so old generic rows can still land in
      // the intended slot while the new role titles are shown in the UI.
      final baseRoles = _committee
          .map((m) => (m['role'] ?? '').toString())
          .toList();
      final used = List<bool>.filled(_committee.length, false);

      for (final row in rows) {
        final rowRole = (row['role'] ?? '').toString();
        final isKnownRole = baseRoles.contains(rowRole);
        int? index;

        if (isNrrClub) {
          index = _resolveCommitteeIndexFromDisplayOrder(row['display_order']);
          if (index != null && used[index]) {
            index = null;
          }
        }

        // First, try to match by role name against the template list.
        if (index == null && isKnownRole) {
          for (var i = 0; i < baseRoles.length; i++) {
            if (!used[i] && baseRoles[i] == rowRole) {
              index = i;
              break;
            }
          }
        }

        // If this is a custom role (not in the template list),
        // fall back to using display_order as either 0-based or 1-based.
        if (!isKnownRole && index == null) {
          final displayOrderIndex = _resolveCommitteeIndexFromDisplayOrder(
            row['display_order'],
          );
          if (displayOrderIndex != null && !used[displayOrderIndex]) {
            index = displayOrderIndex;
          }
        }

        if (index == null || index < 0 || index >= _committee.length) {
          continue;
        }

        final target = _committee[index];
        used[index] = true;
        target['id'] = row['id']?.toString();
        if (!isNrrClub || isKnownRole) {
          target['role'] = row['role'] ?? target['role'];
        }
        target['name'] = (row['name'] ?? '').toString();
        target['email'] = (row['email'] ?? '').toString();
        final rawUserId = row['user_id'];
        target['userId'] = rawUserId == null ? null : rawUserId.toString();
        target['avatarUrl'] = row['avatar_url']?.toString() ?? '';
      }

      if (!mounted) return;
      setState(() {
        _clubConfig = config;
        _adminClub = clubName;
        _committeeLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading club config or committee: $e');
      if (!mounted) return;
      setState(() {
        _clubConfig = null;
        _adminClub = null;
        _committeeLoaded = true;
      });
    }
  }

  Future<void> _loadDeletionRequestCount() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final data = await _supabase
          .from('notifications')
          .select('id, body, is_read')
          .eq('user_id', currentUser.id)
          .eq('is_read', false)
          .ilike('body', '%[route:club_committee]%');

      if (!mounted) return;
      setState(() {
        _deletionRequestCount = (data as List).length;
      });
    } catch (e) {
      debugPrint('Error loading deletion request count: $e');
    }
  }

  Future<void> _clearCommitteeMember(int index) async {
    final id = _committee[index]['id']?.toString();

    setState(() {
      _committee[index]['name'] = '';
      _committee[index]['email'] = '';
      _committee[index]['userId'] = null;
      _committee[index]['avatarUrl'] = null;
    });

    if (id == null || id.isEmpty) {
      return;
    }

    try {
      await _supabase
          .from('committee_roles')
          .update({
            'name': '',
            'email': '',
            'user_id': null,
            'avatar_url': null,
          })
          .eq('id', id);
    } catch (e) {
      debugPrint('Error clearing committee member: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not clear member: $e')));
    }
  }

  void _editMember(int index) {
    if (!_isAdmin) return;

    final member = _committee[index];

    // Admins don't need to backspace to replace someone: fields can start
    // blank with the current holder shown as a hint, but we also keep
    // controllers around to allow editing.
    final nameController = TextEditingController(
      text: (member['name'] ?? '').toString(),
    );
    final emailController = TextEditingController(
      text: (member['email'] ?? '').toString(),
    );

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
            if ((member['name'] ?? '').toString().isNotEmpty ||
                (member['email'] ?? '').toString().isNotEmpty)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _clearCommitteeMember(index);
                },
                child: const Text(
                  'Clear role',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
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
                    _committee[index]['userId'] = null;
                    _committee[index]['avatarUrl'] = null;
                  } else {
                    _committee[index]['email'] = newEmail;
                  }
                });
                Navigator.pop(context);

                final id = _committee[index]['id']?.toString();
                try {
                  final dynamic rawUserId = _committee[index]['userId'];
                  final String? userIdValue;
                  if (rawUserId == null) {
                    userIdValue = null;
                  } else {
                    final s = rawUserId.toString().trim();
                    userIdValue = s.isEmpty ? null : s;
                  }

                  if (id != null && id.isNotEmpty) {
                    // Existing row: update without needing the club name.
                    final role = (_committee[index]['role'] ?? '').toString();
                    await _supabase
                        .from('committee_roles')
                        .update({
                          'role': role,
                          'name': newName,
                          'email': newName.isEmpty ? '' : newEmail,
                          'user_id': userIdValue,
                          'avatar_url': _committee[index]['avatarUrl'] ?? null,
                          'display_order': index,
                        })
                        .eq('id', id);
                  } else {
                    // Otherwise insert a new row for this club/role.
                    final club = _adminClub ?? _clubConfig?.name;
                    if (club == null || club.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not save member: club is not set',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    final role = (_committee[index]['role'] ?? '').toString();
                    final insertData = {
                      'club': club,
                      'role': role,
                      'name': newName,
                      'email': newName.isEmpty ? '' : newEmail,
                      'user_id': userIdValue,
                      'avatar_url': _committee[index]['avatarUrl'] ?? null,
                      'display_order': index,
                    };

                    final inserted = await _supabase
                        .from('committee_roles')
                        .insert(insertData)
                        .select('id')
                        .single();

                    final newId = inserted['id']?.toString();
                    if (newId != null && newId.isNotEmpty && mounted) {
                      setState(() {
                        _committee[index]['id'] = newId;
                      });
                    }
                  }
                } catch (e) {
                  debugPrint('Error saving committee member: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not save member: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMemberSelector(
    int index,
    TextEditingController nameController,
    TextEditingController emailController,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final messenger = ScaffoldMessenger.of(context);

    final localSearchController = TextEditingController();
    bool searching = false;
    List<Map<String, dynamic>> results = [];

    Future<void> doSearch(String term, StateSetter setModalState) async {
      if (term.trim().length < 2) {
        setModalState(() {
          searching = false;
          results = [];
        });
        return;
      }

      setModalState(() {
        searching = true;
      });

      try {
        final clubName = _adminClub;

        var query = _supabase
            .from('user_profiles')
            .select('id, full_name, email, avatar_url, club');

        if (clubName != null && clubName.isNotEmpty) {
          query = query.eq('club', clubName);
        }

        final data = await query
            .or('full_name.ilike.%$term%,email.ilike.%$term%')
            .limit(20);

        setModalState(() {
          results = List<Map<String, dynamic>>.from(data);
          searching = false;
        });
      } catch (e) {
        setModalState(() {
          searching = false;
        });
        messenger.showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
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
                              backgroundColor: primary.withOpacity(0.25),
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
                              final existingCommitteeEmail =
                                  (emailController.text).trim();
                              setState(() {
                                _committee[index]['name'] =
                                    (user['full_name'] ?? '') as String;
                                // Staff roles should use the club-managed role
                                // email, not the member's personal app email.
                                _committee[index]['email'] =
                                    existingCommitteeEmail;
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
            'id, full_name, email, uka_number, membership_type, is_admin, admin_since, is_blocked, block_reason, soft_removed_at, club',
          );

      if (clubName != null && clubName.isNotEmpty) {
        query = query.eq('club', clubName);
      }

      final data = await query
          .or(
            'full_name.ilike.%$term%,email.ilike.%$term%,uka_number.ilike.%$term%',
          )
          .limit(20);

      final results = List<Map<String, dynamic>>.from(
        data,
      ).map((row) => {...row, '_result_type': 'profile'}).toList();

      if (clubName != null && clubName.isNotEmpty) {
        final inviteRows = await _supabase
            .from('club_member_invites')
            .select(
              'id, full_name, uka_number, invite_code, is_active, claimed_by_user_id, claimed_at, club_name, created_at',
            )
            .eq('club_name', clubName)
            .eq('is_active', true)
            .filter('claimed_by_user_id', 'is', null)
            .or('full_name.ilike.%$term%,uka_number.ilike.%$term%')
            .order('created_at', ascending: false)
            .limit(20);

        final existingUkas = results
            .map((row) => (row['uka_number'] ?? '').toString().trim())
            .where((uka) => uka.isNotEmpty)
            .map((uka) => uka.toUpperCase().replaceAll(RegExp(r'[\s-]+'), ''))
            .toSet();

        for (final row in inviteRows) {
          final invite = Map<String, dynamic>.from(row);
          final uka = (invite['uka_number'] ?? '')
              .toString()
              .trim()
              .toUpperCase()
              .replaceAll(RegExp(r'[\s-]+'), '');
          if (uka.isNotEmpty && existingUkas.contains(uka)) continue;
          results.add({...invite, '_result_type': 'invite'});
        }
      }

      setModalState(() {
        _searchResults = results;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setModalState(() => _searching = false);
    }
  }

  Future<void> _showInviteCode(Map<String, dynamic> invite) async {
    final code = (invite['invite_code'] ?? '').toString();
    final name = (invite['full_name'] ?? 'Member').toString();
    final uka = (invite['uka_number'] ?? '').toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final primary = Theme.of(dialogContext).colorScheme.primary;
        return AlertDialog(
          backgroundColor: const Color(0xFF0F111A),
          title: Text('Member invite code', style: TextStyle(color: primary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white)),
              if (uka.isNotEmpty)
                Text(
                  'UKA: $uka',
                  style: const TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 14),
              SelectableText(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Send this code to the member so they can continue registration.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
          ],
        );
      },
    );
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

  Future<void> _openMigrationDialog(
    Map<String, dynamic> user,
    StateSetter setModalState,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final fromClub = (user['club'] as String?) ?? _adminClub;
    if (fromClub == null || fromClub.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Member has no club assigned.')),
      );
      return;
    }

    List<String> clubs = [];
    try {
      final data = await _supabase
          .from('app_clubs')
          .select('name')
          .order('name', ascending: true);

      clubs = [
        for (final row in data)
          if ((row['name'] ?? '').toString().isNotEmpty &&
              (row['name'] as String) != fromClub)
            (row['name'] as String),
      ];
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load clubs: $e')),
      );
      return;
    }

    if (clubs.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No other registered clubs available for migration.'),
        ),
      );
      return;
    }

    String? selectedClub;
    String? generatedCode;
    String? errorText;

    String _initials(String name) {
      final buffer = StringBuffer();
      for (final raw in name.split(' ')) {
        final letters = raw.replaceAll(RegExp(r'[^A-Za-z]'), '').trim();
        if (letters.isNotEmpty) {
          buffer.write(letters[0].toUpperCase());
        }
      }
      final result = buffer.toString();
      return result.isEmpty ? name : result;
    }

    String _randomSuffix(int length) {
      const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
      final rand = Random.secure();
      return List.generate(
        length,
        (_) => chars[rand.nextInt(chars.length)],
      ).join();
    }

    // Show dialog to pick destination club and generate code
    await showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final primary = colorScheme.primary;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F111A),
              title: Text(
                'Generate migration code',
                style: TextStyle(color: primary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member: ${user['full_name'] ?? '—'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current club: $fromClub',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedClub,
                        dropdownColor: const Color(0xFF151828),
                        decoration: const InputDecoration(
                          labelText: 'Destination club',
                          labelStyle: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        items: clubs
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setStateDialog(() {
                            selectedClub = v;
                            errorText = null;
                          });
                        },
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (generatedCode != null) ...[
                      const Text(
                        'Migration code generated:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151828),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          generatedCode!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tip: copy this message and send it to the member.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () async {
                          final destination = selectedClub ?? 'the new club';
                          final instructions =
                              '''
RunRank account migration for ${user['full_name'] ?? 'your account'}

New club: $destination
Migration code: $generatedCode

How to use this code:
1. Open the RunRank app and log out if you are currently logged in.
2. On the first screen, tap 'Migrate an Account'.
3. Choose $destination as your new club.
4. Enter the migration code exactly as shown above.

For security we recommend using this code within the next few days. After it has been used once it will no longer be valid.
''';

                          await Clipboard.setData(
                            ClipboardData(text: instructions),
                          );

                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Migration instructions copied'),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.copy,
                          size: 18,
                          color: Colors.white70,
                        ),
                        label: const Text(
                          'Copy code and instructions',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedClub == null || selectedClub!.isEmpty) {
                      setStateDialog(
                        () => errorText = 'Please select a destination club.',
                      );
                      return;
                    }

                    final code =
                        'MIG-${_initials(fromClub)}-${_initials(selectedClub!)}-${_randomSuffix(5)}';

                    try {
                      await _supabase.from('membership_migrations').insert({
                        'user_id': user['id'],
                        'from_club': fromClub,
                        'to_club': selectedClub,
                        'migration_code': code,
                        'status': 'approved',
                      });

                      setStateDialog(() {
                        generatedCode = code;
                      });

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Migration code generated: $code'),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Could not create migration code: $e'),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: const Text('Generate code'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _launchEmail({
    String? to,
    required String subject,
    String? body,
  }) async {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = body != null && body.isNotEmpty
        ? Uri.encodeComponent(body)
        : null;
    final query = [
      'subject=$encodedSubject',
      if (encodedBody != null) 'body=$encodedBody',
    ].join('&');

    final uri = Uri(scheme: 'mailto', path: to, query: query);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _confirmRemoveProfile(
    Map<String, dynamic> user,
    StateSetter setModalState,
  ) {
    final rawSoftRemovedAt = user['soft_removed_at'];
    String? softRemovedIso;
    if (rawSoftRemovedAt is String) {
      softRemovedIso = rawSoftRemovedAt;
    } else if (rawSoftRemovedAt is DateTime) {
      softRemovedIso = rawSoftRemovedAt.toIso8601String();
    }
    String? softRemovedDisplay;
    if (softRemovedIso != null && softRemovedIso.length >= 10) {
      softRemovedDisplay = softRemovedIso.substring(0, 10);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: const Text(
          'Remove Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Member: ${user['full_name'] ?? '—'}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              'Email: ${user['email'] ?? '—'}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (softRemovedDisplay != null)
              Text(
                'This member was soft-removed on $softRemovedDisplay. Full Delete is the final step and should only be used after the grace period has passed without membership renewal, or when the member has directly requested permanent account removal. You can also cancel the soft removal from here.',
                style: const TextStyle(color: Colors.white70),
              )
            else
              const Text(
                'Soft removal immediately blocks access and clears optional profile details while keeping the account in a grace-period state. If the member renews, you can cancel the soft removal later. If they do not renew, or they request permanent account removal, you can later return here to perform Full Delete.',
                style: TextStyle(color: Colors.white70),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (softRemovedDisplay == null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _softRemoveProfile(user, setModalState);
              },
              child: const Text(
                'Soft remove now',
                style: TextStyle(color: Colors.redAccent),
              ),
            )
          else ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _cancelSoftRemoval(user, setModalState);
              },
              child: const Text(
                'Cancel soft removal',
                style: TextStyle(color: Colors.lightGreenAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmFullDelete(user, setModalState);
              },
              child: const Text(
                'Full Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
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
            'soft_removed_at': DateTime.now().toIso8601String(),
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

  Future<void> _cancelSoftRemoval(
    Map<String, dynamic> user,
    StateSetter setModalState,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'is_blocked': false,
            'block_reason': null,
            'soft_removed_at': null,
          })
          .eq('id', user['id'] as String);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Soft removal cancelled and user unblocked'),
        ),
      );

      await _searchUsers(_searchController.text, setModalState);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to cancel soft removal: $e')),
      );
    }
  }

  Future<void> _confirmFullDelete(
    Map<String, dynamic> user,
    StateSetter setModalState,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: const Text(
          'Confirm Full Delete',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete this member\'s account data in RunRank. Posts and club records may be anonymised but access to the app will be fully removed. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, permanently delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final userId = user['id'] as String;
      final response = await _supabase.functions.invoke(
        'full-delete-user',
        body: {'userId': userId},
      );

      if (response.status == 200) {
        final remainingProfile = await _supabase
            .from('user_profiles')
            .select('id')
            .eq('id', userId)
            .maybeSingle();

        final responseData = response.data;
        final functionConfirmedDelete =
            responseData is Map && responseData['deleted'] == true;
        final profileDeleted = remainingProfile == null;

        if (functionConfirmedDelete || profileDeleted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Account fully deleted')),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Delete request completed, but the profile still exists. Check the full-delete-user function deployment.',
              ),
            ),
          );
        }

        await _searchUsers(_searchController.text, setModalState);
      } else {
        final responseData = response.data;
        final detail = responseData is Map ? responseData['error'] : null;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              detail == null
                  ? 'Full delete failed (code ${response.status}). Please check the server logs.'
                  : 'Full delete failed: $detail',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Full delete failed: $e')));
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
                        hintText: 'Search by name, email or UKA',
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
                            final isInvite = user['_result_type'] == 'invite';
                            final isUserAdmin = user['is_admin'] == true;
                            final isBlocked = user['is_blocked'] == true;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                            isInvite
                                                ? 'Pending registration • UKA ${user['uka_number'] ?? '—'}'
                                                : user['email'] ?? '',
                                            style: TextStyle(
                                              color: isInvite
                                                  ? Colors.amberAccent
                                                  : Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                Chip(
                                                  label: Text(
                                                    isInvite
                                                        ? 'Invite pending'
                                                        : isUserAdmin
                                                        ? 'Admin'
                                                        : 'Reader',
                                                  ),
                                                  backgroundColor: isInvite
                                                      ? Colors.amber
                                                            .withOpacity(0.2)
                                                      : isUserAdmin
                                                      ? Colors.green
                                                            .withOpacity(0.2)
                                                      : Colors.blue.withOpacity(
                                                          0.2,
                                                        ),
                                                  labelStyle: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                if (!isInvite)
                                                  Chip(
                                                    label: Text(
                                                      user['membership_type'] ??
                                                          '—',
                                                    ),
                                                    backgroundColor: Colors
                                                        .white
                                                        .withOpacity(0.08),
                                                    labelStyle: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                if (isBlocked) ...[
                                                  const SizedBox(width: 6),
                                                  Chip(
                                                    label: const Text(
                                                      'Blocked',
                                                    ),
                                                    backgroundColor: Colors.red
                                                        .withOpacity(0.2),
                                                    labelStyle: const TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
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
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (isInvite)
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        tooltip: 'Show invite code',
                                        onPressed: () => _showInviteCode(user),
                                        icon: const Icon(
                                          Icons.vpn_key_outlined,
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                    if (!isInvite) ...[
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        tooltip: isUserAdmin
                                            ? 'Remove admin'
                                            : 'Make admin',
                                        onPressed: () => _setAdminStatus(
                                          user,
                                          !isUserAdmin,
                                          setModalState,
                                        ),
                                        icon: Icon(
                                          isUserAdmin
                                              ? Icons.security_update_warning
                                              : Icons.verified_user,
                                          color: isUserAdmin
                                              ? Colors.orangeAccent
                                              : Colors.greenAccent,
                                        ),
                                      ),
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
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        tooltip: isBlocked
                                            ? 'Unblock'
                                            : 'Block',
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
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        tooltip: 'Generate migration code',
                                        onPressed: () => _openMigrationDialog(
                                          user,
                                          setModalState,
                                        ),
                                        icon: const Icon(
                                          Icons.compare_arrows,
                                          color: Colors.amber,
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        tooltip: 'Generate reset code',
                                        onPressed: () =>
                                            _openPasswordResetCodeDialog(user),
                                        icon: const Icon(
                                          Icons.password_rounded,
                                          color: Colors.lightBlueAccent,
                                        ),
                                      ),
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

  Future<void> _openPasswordResetCodeDialog(Map<String, dynamic> user) async {
    final messenger = ScaffoldMessenger.of(context);
    final club = (user['club'] ?? _adminClub ?? '').toString().trim();
    final memberName = (user['full_name'] ?? 'Member').toString();
    final ukaNumber = (user['uka_number'] ?? '').toString().trim();
    String? generatedCode;

    String initials(String name) {
      final buffer = StringBuffer();
      for (final raw in name.split(' ')) {
        final letters = raw.replaceAll(RegExp(r'[^A-Za-z]'), '').trim();
        if (letters.isNotEmpty) {
          buffer.write(letters[0].toUpperCase());
        }
      }
      final result = buffer.toString();
      return result.isEmpty ? 'RR' : result;
    }

    String randomSuffix(int length) {
      const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
      final rand = Random.secure();
      return List.generate(
        length,
        (_) => chars[rand.nextInt(chars.length)],
      ).join();
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final primary = colorScheme.primary;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F111A),
              title: Text(
                'Generate reset code',
                style: TextStyle(color: primary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member: $memberName',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Club: ${club.isEmpty ? '—' : club}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (ukaNumber.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'UKA: $ukaNumber',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Create a one-off code that the member can use in the app to set a new password. The code expires after 7 days and can only be used once.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    if (generatedCode != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Reset code generated:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151828),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          generatedCode!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final instructions =
                              '''
RunRank password reset for $memberName

Reset code: $generatedCode

How to use this code:
1. Open the RunRank app.
2. On the login screen, tap "Forgot password?".
3. Tap "I have a reset code".
4. Enter your UKA number, this reset code, and your new password.

This code can be used once and will expire in 7 days.
''';

                          await Clipboard.setData(
                            ClipboardData(text: instructions),
                          );
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Reset instructions copied'),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.copy,
                          size: 18,
                          color: Colors.white70,
                        ),
                        label: const Text(
                          'Copy code and instructions',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (club.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Could not determine the member club.'),
                        ),
                      );
                      return;
                    }

                    final code = 'RST-${initials(club)}-${randomSuffix(6)}';

                    try {
                      await _supabase.from('password_reset_codes').insert({
                        'user_id': user['id'],
                        'club': club,
                        'reset_code': code,
                        'status': 'issued',
                        'created_by': _supabase.auth.currentUser?.id,
                      });

                      setStateDialog(() {
                        generatedCode = code;
                      });

                      messenger.showSnackBar(
                        SnackBar(content: Text('Reset code generated: $code')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Could not create reset code: $e'),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: const Text('Generate code'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showContactForm(int index) async {
    final member = _committee[index];
    final email = (member['email'] ?? '').toString().trim();
    if (email.isEmpty) return;

    final role = (member['role'] ?? '').toString().trim();
    final name = (member['name'] ?? '').toString().trim();

    final subject = role.isNotEmpty
        ? 'RunRank – $role enquiry'
        : 'RunRank club committee enquiry';
    final bodyHeader = name.isNotEmpty ? 'Dear $name,' : 'Dear club official,';

    // Create a notification for the specific admin role holder
    // so their committee email icon can glow when there are
    // unread contact requests.
    final rawUserId = member['userId'];
    final userId = rawUserId?.toString().trim();
    if (userId != null && userId.isNotEmpty) {
      try {
        await NotificationService.notifyUser(
          userId: userId,
          title: 'Committee email opened',
          body:
              'A club member has opened an email draft to you for your role as $role.',
          route: 'club_committee',
        );
      } catch (e) {
        debugPrint('Error creating committee email notification: $e');
      }
    }

    await _launchEmail(to: email, subject: subject, body: '$bodyHeader\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = _brandPrimary(colorScheme);
    final accent = _brandAccent(colorScheme);

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
                        primary.withOpacity(0.85),
                        accent.withOpacity(0.75),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Acknowledgement email',
                          onPressed: () {
                            // Reset the local counter when the icon is tapped
                            setState(() {
                              _deletionRequestCount = 0;
                            });

                            // Open the device email app with a generic
                            // acknowledgement template that admins can use
                            // when replying to member enquiries.
                            _launchEmail(
                              subject: 'RunRank club enquiry – acknowledgement',
                              body:
                                  'Thank you for your email. We will endeavour to resolve your query as soon as possible.\n\nYour Admin Team',
                            );
                          },
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.email_outlined,
                                color: _deletionRequestCount > 0
                                    ? Colors.amberAccent
                                    : primary,
                              ),
                              if (_deletionRequestCount > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '$_deletionRequestCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Admin controls',
                          onPressed: _openAdminControls,
                          icon: Icon(
                            Icons.admin_panel_settings,
                            color: primary,
                          ),
                        ),
                      ],
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
                              primary.withOpacity(0.12),
                              accent.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: primary.withOpacity(0.6),
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
                                        Icons.email_outlined,
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

  // Brand-aware helpers: if both primary and accent in the
  // global theme are very light (near white), fall back to
  // NNBR yellow/blue so committee headers and cards keep the
  // expected combined club colours.

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
