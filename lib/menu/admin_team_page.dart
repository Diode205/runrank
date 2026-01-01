import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/services/user_service.dart';

class AdministrativeTeamPage extends StatefulWidget {
  const AdministrativeTeamPage({super.key});

  @override
  State<AdministrativeTeamPage> createState() => _AdministrativeTeamPageState();
}

class _AdministrativeTeamPageState extends State<AdministrativeTeamPage> {
  final _supabase = Supabase.instance.client;
  bool _isAdmin = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  final List<Map<String, String>> _committee = [
    {'role': 'President', 'name': 'Noel Spruce', 'email': ''},
    {
      'role': 'Chairperson',
      'name': 'Ness Dent',
      'email': 'chairperson@nnbr.co.uk',
    },
    {'role': 'Vice-Chairperson', 'name': 'Richard West', 'email': ''},
    {'role': 'Secretary', 'name': 'Gav Dent', 'email': 'secretary@nnbr.co.uk'},
    {
      'role': 'Treasurer',
      'name': 'Peter Hill',
      'email': 'treasurer@nnbr.co.uk',
    },
    {'role': 'Membership Secretary', 'name': 'Libby Ashton', 'email': ''},
    {
      'role': 'Minutes Secretary',
      'name': 'Rachel Welch',
      'email': 'minutes_secretary@nnbr.co.uk',
    },
    {'role': 'Clothing Manager', 'name': 'Sarah Morter', 'email': ''},
    {'role': 'Club Head Coach', 'name': 'Karen Balcombe', 'email': ''},
    {'role': 'Equipment Store Manager', 'name': 'Phil King', 'email': ''},
    {'role': 'General Committee Member', 'name': 'Neil Adams', 'email': ''},
    {'role': 'General Committee Member', 'name': 'Tony Witmond', 'email': ''},
    {'role': 'Webmaster', 'name': 'John Fagan', 'email': ''},
    {'role': 'Press Officer', 'name': 'John Worrall', 'email': ''},
  ];

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    _isAdmin = await UserService.isAdmin();
    if (mounted) setState(() {});
  }

  void _editMember(int index) {
    if (!_isAdmin) return;

    final member = _committee[index];
    final nameController = TextEditingController(text: member['name']);
    final emailController = TextEditingController(text: member['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Edit ${member['role']}',
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.white70),
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
            onPressed: () {
              setState(() {
                _committee[index]['name'] = nameController.text.trim();
                _committee[index]['email'] = emailController.text.trim();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
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
      final data = await _supabase
          .from('user_profiles')
          .select(
            'id, full_name, email, membership_type, is_admin, admin_since, is_blocked, block_reason',
          )
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
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: const Text(
          'Send warning',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
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
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0F111A),
          title: const Text(
            'Block user',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Block'),
            ),
          ],
        ),
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

  void _openAdminControls() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
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
                        const Icon(
                          Icons.admin_panel_settings,
                          color: Color(0xFFFFD700),
                        ),
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
                          borderSide: const BorderSide(color: Colors.white24),
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
                                      Row(
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
                                          const SizedBox(width: 6),
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
                                          if (isBlocked) ...[
                                            const SizedBox(width: 6),
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
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isAdmin
                                            ? Colors.orangeAccent.withOpacity(
                                                0.15,
                                              )
                                            : Colors.greenAccent.withOpacity(
                                                0.15,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
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
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        tooltip: 'Warn user',
                                        onPressed: () =>
                                            _warnUser(user, setModalState),
                                        icon: const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isBlocked
                                            ? Colors.lightGreenAccent
                                                  .withOpacity(0.15)
                                            : Colors.redAccent.withOpacity(
                                                0.15,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Contact ${member['name']}',
          style: const TextStyle(color: Color(0xFFFFD700)),
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
                    borderSide: const BorderSide(
                      color: Color(0xFF0055FF),
                      width: 2,
                    ),
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
                    borderSide: const BorderSide(
                      color: Color(0xFF0055FF),
                      width: 2,
                    ),
                  ),
                  alignLabelWithHint: true,
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
          ElevatedButton.icon(
            onPressed: () {
              if (subjectController.text.trim().isEmpty ||
                  messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // TODO: Store enquiry in Supabase or send via email service
              // For now, show a confirmation
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Message sent to ${member['name']}. Thank you!',
                  ),
                  backgroundColor: const Color(0xFF0055FF),
                ),
              );
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A1A3A), Color(0xFF0D2F5A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: const Color(0xFF1E406A),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people,
                        color: Color(0xFFFFD700),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'The NNBR Team Committee',
                              style: TextStyle(
                                color: Color.fromARGB(255, 238, 228, 30),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'For general enquiries, please contact The Chairperson or The Secretary via email.',
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
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
                      icon: const Icon(
                        Icons.admin_panel_settings,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _committee.length,
              itemBuilder: (context, index) {
                final member = _committee[index];
                final hasEmail = (member['email'] ?? '').isNotEmpty;

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
                      color: const Color(0xFF0055FF).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0055FF),
                                    Color(0xFF0088FF),
                                  ],
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['role'] ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFF56D3FF),
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
                                      padding: const EdgeInsets.only(top: 6),
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
                            const SizedBox(width: 40), // Space for buttons
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
                                  color: const Color(
                                    0xFFFFD700,
                                  ).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withOpacity(0.4),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Color(0xFFFFD700),
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
                                  color: const Color(
                                    0xFF56D3FF,
                                  ).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF56D3FF,
                                    ).withOpacity(0.4),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.send,
                                  color: Color(0xFF56D3FF),
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
