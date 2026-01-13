import 'package:flutter/material.dart';
import 'package:runrank/services/malcolm_ball_award_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MalcolmBallAwardPage extends StatefulWidget {
  const MalcolmBallAwardPage({super.key});

  @override
  State<MalcolmBallAwardPage> createState() => _MalcolmBallAwardPageState();
}

class _MalcolmBallAwardPageState extends State<MalcolmBallAwardPage> {
  final _service = MalcolmBallAwardService();
  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();
  final _commentController = TextEditingController();

  bool _loading = true;
  List<AwardNominee> _nominees = [];
  List<AwardWinnerItem> _winners = [];
  bool _isAdmin = false;
  List<String> _memberNames = [];
  // Nominee emoji counts no longer displayed
  bool _storyExpanded = false;
  List<AwardChatMessage> _chatMessages = [];
  Map<String, Map<String, int>> _messageEmojiCounts = {};
  DateTime? _votingEndsAt;

  @override
  void initState() {
    super.initState();
    _load();
    _service.subscribeToChanges(
      onAnyChange: () {
        // Refresh nominees and comments whenever any table changes
        _load();
      },
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final nominees = await _service.fetchNominees();
      final winners = await _service.fetchWinners();
      final admin = await UserService.isAdmin();
      final membersRows = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name')
          .order('full_name');
      final memberNames = (membersRows as List)
          .map((r) => (r['full_name'] as String?)?.trim())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      // Nominee emoji counts removed from UI
      final chat = await _service.fetchChatMessages();
      final chatCounts = await _service.fetchMessageEmojiCounts(
        chat.map((m) => m.id).toSet(),
      );
      final votingEndsAt = await _service.fetchVotingEndsAt();
      if (!mounted) return;
      setState(() {
        _nominees = nominees;
        _winners = winners;
        _isAdmin = admin;
        _memberNames = memberNames;
        _chatMessages = chat;
        _messageEmojiCounts = chatCounts;
        _votingEndsAt = votingEndsAt;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _commentController.dispose();
    _service.unsubscribe();
    super.dispose();
  }

  Future<void> _submitNomination() async {
    final name = _nameController.text.trim();
    final reason = _reasonController.text.trim();
    if (name.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a name and reason')),
      );
      return;
    }
    try {
      await _service.submitNomination(name: name, reason: reason);
      _nameController.clear();
      _reasonController.clear();
      try {
        await NotificationService.notifyAllUsers(
          title: 'New nomination',
          body: '$name was nominated for the Malcolm Ball Award',
          route: 'malcolm_ball_award',
        );
      } catch (_) {}
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nomination submitted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Nomination failed: $e')));
    }
  }

  Future<void> _vote(String nomineeId) async {
    try {
      await _service.voteNominee(nomineeId);
      // Notify all users about the vote with route tag for deep link
      try {
        final nomineeName = _nominees
            .firstWhere(
              (n) => n.id == nomineeId,
              orElse: () => AwardNominee(id: '', name: 'a nominee', votes: 0),
            )
            .name;
        await NotificationService.notifyAllUsers(
          title: 'New vote',
          body: 'A vote was cast for ' + nomineeName,
          route: 'malcolm_ball_award',
        );
      } catch (_) {}
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _reactToMessage(String messageId, String emoji) async {
    try {
      await _service.addMessageEmoji(messageId: messageId, emoji: emoji);
      try {
        await NotificationService.notifyAllUsers(
          title: 'New reaction',
          body: 'Someone reacted $emoji in Malcolm Ball chat',
          route: 'malcolm_ball_award',
        );
      } catch (_) {}
      final counts = await _service.fetchMessageEmojiCounts({messageId});
      if (!mounted) return;
      setState(() {
        _messageEmojiCounts[messageId] = counts[messageId] ?? {};
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reaction failed: $e')));
    }
  }

  // _addComment removed in favor of general chat

  @override
  Widget build(BuildContext context) {
    const headerHeight = 260.0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Malcolm Ball Award 2026'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Fixed header image
                SizedBox(
                  height: headerHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/malcolmball.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black54],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Title overlay
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'The Malcolm Ball Inspirational\nRunner Award 2026',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'The Nominations',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable content overlays below the image
                RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: headerHeight + 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _storyCard(),
                        const SizedBox(height: 16),
                        _hallOfFameSection(),
                        const SizedBox(height: 16),
                        _nomineesSection(),
                        const SizedBox(height: 16),
                        _nominationForm(),
                        const SizedBox(height: 16),
                        _commentsSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _hallOfFameSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        // Reduced top padding; normal bottom since button sits after content
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5C542), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Centered header
            const SizedBox(
              height: 36,
              child: Center(
                child: Text(
                  '🏆 Hall Of Fame 🏆',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_winners.isEmpty)
              const Text(
                'No winners recorded yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final winners = [..._winners]
                    ..sort((a, b) => b.year.compareTo(a.year));
                  const spacing = 10.0;
                  final itemWidth = (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 8,
                    children: winners.map((w) {
                      return SizedBox(
                        width: itemWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x33F5C542),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF5C542),
                                ),
                              ),
                              child: Text(
                                w.year.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                w.name,
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            if (_isAdmin)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: IconButton(
                    tooltip: 'Add previous winner',
                    onPressed: _showAddWinnerDialog,
                    icon: const Icon(Icons.add, color: Color(0xFFFFD700)),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddWinnerDialog() async {
    if (!_isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Admins only')));
      return;
    }
    final yearController = TextEditingController();
    final nameController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F111A),
          title: const Text(
            'Add Previous Winner',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Year (e.g. 2024)',
                ),
              ),
              const SizedBox(height: 8),
              if (_memberNames.isNotEmpty) ...[
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue tv) {
                    final q = tv.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable<String>.empty();
                    return _memberNames.where(
                      (n) => n.toLowerCase().contains(q),
                    );
                  },
                  onSelected: (sel) {
                    nameController.text = sel;
                  },
                  fieldViewBuilder:
                      (ctx2, controller, focusNode, onFieldSubmitted) {
                        controller.text = nameController.text;
                        controller.addListener(() {
                          nameController.text = controller.text;
                        });
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onSubmitted: (_) => onFieldSubmitted(),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Search Member (Optional)',
                          ),
                        );
                      },
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Winner Name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    final yearRaw = yearController.text.trim();
    final name = nameController.text.trim();
    final year = int.tryParse(yearRaw);
    if (year == null || name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid year and name')),
      );
      return;
    }
    try {
      await _service.addWinner(year: year, name: name);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Winner added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add winner: $e')));
    }
  }

  // (header moved to top-level Stack in build)

  Widget _storyCard() {
    const body =
        'He has run across the mountainous Lake District terrain, completed 39 marathons, run for the England cross country team and gone through scores of trainers.\n\n'
        'An amateur running enthusiast Malcolm Ball, from Ridgeway in Cromer, has no plans to give up.\n'
        'Mr Ball, who served as a Royal Marines Commando for two years in Malaya as a teenager for his National Service, is a member of the North Norfolk Beach Runners.\n'
        'He has completed 80 Parkruns, mostly at Sheringham Park, but also at King\'s Lynn and Brighton.\n'
        'He won the amateur British Masters Athletics Federation 10 mile championships in the over 80s category in 97 minutes and nine seconds - nearly 28 minutes faster than the second place runner.\n'
        'His running accomplishments include completing the gruelling Lakeland Trails races across the Lake District when he was between 69 and 72-years-old and being called up twice for the England amateur cross country team.\n'
        'He has also completed eight marathons in under three hours.\n'
        'His fastest marathon time was two hours, 56 minutes and 49 seconds at London in 1990.\n'
        'As well as running 35-40 miles a week, Mr Ball goes to the gym every day and attends aqua Zumba and aqua fitness classes three times a week.\n'
        'He also trains newcomers to the North Norfolk Beach Runners.';
    const credit =
        '         — Sophie Wyllie, Eastern Daily Press, 27 March 2015.  Picture: Mark Bullimore.  Image: Archant Norfolk 2015)';

    final breakIdx = body.indexOf('\n\n');
    final firstPara = breakIdx > 0 ? body.substring(0, breakIdx) : body;
    final rest = breakIdx > 0 ? body.substring(breakIdx + 2) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5C542), width: 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstPara,
                  style: const TextStyle(color: Colors.white, height: 1.35),
                ),
                if (!_storyExpanded && rest.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _storyExpanded = true),
                      child: const Text('Read more ⌄'),
                    ),
                  ),
                ],
                if (_storyExpanded && rest.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    rest,
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _storyExpanded = false),
                      child: const Text('Show less ⌃'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    credit,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _nomineesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'And The Nominees Are...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isAdmin)
                IconButton(
                  tooltip: 'View vote tally',
                  onPressed: _showVotesTallyDialog,
                  icon: const Icon(Icons.bar_chart, color: Color(0xFFFFD700)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_nominees.isEmpty)
            const Text(
              'No nominations yet. Be the first to nominate below!',
              style: TextStyle(color: Colors.white70),
            )
          else
            Column(children: _nominees.map((n) => _nomineeRow(n)).toList()),
        ],
      ),
    );
  }

  Widget _nomineeRow(AwardNominee n) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5C542)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              n.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0057B7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _vote(n.id),
            icon: const Icon(Icons.how_to_vote, size: 18),
            label: const Text('Vote'),
          ),
        ],
      ),
    );
  }

  // reactions moved to chat messages

  Widget _nominationForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F111A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF5C542), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '     Nominate An Inspiring NNBR Member',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (_memberNames.isNotEmpty)
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue tv) {
                      final q = tv.text.trim().toLowerCase();
                      if (q.isEmpty) return const Iterable<String>.empty();
                      return _memberNames.where(
                        (n) => n.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (selection) {
                      _nameController.text = selection;
                    },
                    fieldViewBuilder:
                        (ctx, controller, focusNode, onFieldSubmitted) {
                          controller.text = _nameController.text;
                          controller.addListener(() {
                            _nameController.text = controller.text;
                          });
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onSubmitted: (_) => onFieldSubmitted(),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Nominee Full Name (Type Or Pick)',
                            ),
                          );
                        },
                  )
                else
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nominee Full Name',
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reasonController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Reason For Nomination',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _submitNomination,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Submit Nomination'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _votingEndsAt != null
                        ? 'Voting Ends On ${_formatDate(_votingEndsAt!)}'
                        : 'Voting Ends On TBD',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          if (_isAdmin)
            Positioned(
              bottom: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Set Voting End Date',
                onPressed: _pickVotingEndDate,
                icon: const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Color(0xFFFFD700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _commentsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Write A Comment'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _addChatMessage,
              icon: const Icon(Icons.send),
              label: const Text('Post Comment'),
            ),
          ),
          const SizedBox(height: 12),
          ..._chatMessages.map(_chatMessageTile),
        ],
      ),
    );
  }

  Widget _chatMessageTile(AwardChatMessage m) {
    final counts = _messageEmojiCounts[m.id] ?? const {};
    final emojis = ['👍', '🎉', '🏃‍♂️', '❤️'];
    Color borderColor = _membershipColor(m.membershipType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundImage:
                    (m.avatarUrl != null && m.avatarUrl!.isNotEmpty)
                    ? NetworkImage(m.avatarUrl!)
                    : null,
                child: (m.avatarUrl == null || m.avatarUrl!.isEmpty)
                    ? Text(
                        (m.userName.isNotEmpty ? m.userName[0] : '?'),
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(m.createdAt),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(m.content, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...emojis.map(
                        (e) => InkWell(
                          onTap: () => _reactToMessage(m.id, e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e),
                                if ((counts[e] ?? 0) > 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    (counts[e] ?? 0).toString(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _membershipColor(String? membershipType) {
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

  Future<void> _addChatMessage() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    try {
      await _service.addChatMessage(content: text);
      try {
        await NotificationService.notifyAllUsers(
          title: 'New Comment',
          body: text.length > 80 ? text.substring(0, 80) + '…' : text,
          route: 'malcolm_ball_award',
        );
      } catch (_) {}
      _commentController.clear();
      final chat = await _service.fetchChatMessages();
      final chatCounts = await _service.fetchMessageEmojiCounts(
        chat.map((m) => m.id).toSet(),
      );
      if (!mounted) return;
      setState(() {
        _chatMessages = chat;
        _messageEmojiCounts = chatCounts;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Comment Failed: $e')));
    }
  }

  Future<void> _showVotesTallyDialog() async {
    try {
      final tally = await _service.fetchVotesTallyDetailed();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F111A),
          title: const Text(
            'Vote Tally',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: tally.map((t) {
                  final voters = (t['voters'] as List).cast<String>();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t['nominee_name'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x33F5C542),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF5C542),
                                ),
                              ),
                              child: Text(
                                '${t['count']} votes',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (voters.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: voters
                                  .map(
                                    (name) => Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        children: [
                                          const Text(
                                            '• ',
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tally: $e')));
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _pickVotingEndDate() async {
    final initial = _votingEndsAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked == null) return;
    try {
      final dateOnly = DateTime(picked.year, picked.month, picked.day);
      await _service.setVotingEndsAt(dateOnly);
      if (!mounted) return;
      setState(() => _votingEndsAt = dateOnly);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to set date: $e')));
    }
  }
}
