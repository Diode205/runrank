import 'package:flutter/material.dart';
import 'package:runrank/services/malcolm_ball_award_service.dart';
import 'package:runrank/services/user_service.dart';
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
  String? _commentNomineeId;

  bool _loading = true;
  List<AwardNominee> _nominees = [];
  List<AwardCommentItem> _comments = [];
  List<AwardWinnerItem> _winners = [];
  bool _isAdmin = false;
  List<String> _memberNames = [];

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
      final comments = await _service.fetchRecentComments();
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
      if (!mounted) return;
      setState(() {
        _nominees = nominees;
        _comments = comments;
        _winners = winners;
        _isAdmin = admin;
        _memberNames = memberNames;
        _loading = false;
        _commentNomineeId = nominees.isNotEmpty ? nominees.first.id : null;
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
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _react(String nomineeId, String emoji) async {
    try {
      await _service.addEmoji(nomineeId, emoji);
      // We won't reload for emoji reactions to keep UI snappy
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reacted $emoji')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reaction failed: $e')));
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    final nomineeId = _commentNomineeId;
    if (nomineeId == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a nominee and enter a comment')),
      );
      return;
    }
    try {
      await _service.addComment(nomineeId: nomineeId, content: text);
      _commentController.clear();
      final comments = await _service.fetchRecentComments();
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Comment failed: $e')));
    }
  }

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
                              'The Malcolm Ball Inspirational\nRunning Award 2026',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'The Nominations',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
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
                    padding: const EdgeInsets.only(top: headerHeight - 40),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5C542), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Hall Of Fame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isAdmin)
                  OutlinedButton.icon(
                    onPressed: _showAddWinnerDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Previous Winner'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD700),
                      side: const BorderSide(color: Color(0xFFFFD700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_winners.isEmpty)
              const Text(
                'No winners recorded yet.',
                style: TextStyle(color: Colors.white70),
              )
            else
              ..._winners.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        w.year.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          w.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddWinnerDialog() async {
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
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Winner name'),
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
    const credit = '— Sophie Wyllie, Eastern Daily Press, 27 March 2015.  Picture: Mark Bullimore.  Image: Archant Norfolk 2015)';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5C542), width: 1),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: TextStyle(color: Colors.white, height: 1.35),
            ),
            SizedBox(height: 10),
            Text(
              credit,
              style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic, height: 1.3),
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
          const Text(
            'And The Nominees Are...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_nominees.isEmpty)
            const Text(
              'No nominations yet. Be the first to nominate below!',
              style: TextStyle(color: Colors.white70),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _nominees
                  .map((n) => _nomineeCard(n))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _nomineeCard(AwardNominee n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C542)),
      ),
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  n.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x33F5C542),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF5C542)),
                ),
                child: Text(
                  '${n.votes} votes',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0057B7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _vote(n.id),
                  icon: const Icon(Icons.how_to_vote),
                  label: const Text('Vote'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _emojiButton(n.id, '👍'),
              _emojiButton(n.id, '🎉'),
              _emojiButton(n.id, '🏃‍♂️'),
              _emojiButton(n.id, '❤️'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emojiButton(String nomineeId, String emoji) {
    return InkWell(
      onTap: () => _react(nomineeId, emoji),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _nominationForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
              'Nominate an inspiring NNBR runner',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nominee full name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reason for nomination',
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
          ],
        ),
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
          if (_nominees.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _commentNomineeId,
              items: _nominees
                  .map(
                    (n) => DropdownMenuItem(value: n.id, child: Text(n.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _commentNomineeId = v),
              decoration: const InputDecoration(labelText: 'Nominee'),
              dropdownColor: const Color(0xFF0F111A),
              style: const TextStyle(color: Colors.white),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Write a comment about this nominee',
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _addComment,
              icon: const Icon(Icons.send),
              label: const Text('Post Comment'),
            ),
          ),
          const SizedBox(height: 12),
          ..._comments.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B26),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.nomineeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(c.createdAt),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                            const SizedBox(height: 10),
                            if (_memberNames.isNotEmpty)
                              DropdownButtonFormField<String>(
                                value: null,
                                items: _memberNames
                                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                                    .toList(growable: false),
                                onChanged: (val) {
                                  if (val != null) {
                                    _nameController.text = val;
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Or pick from members',
                                ),
                                dropdownColor: const Color(0xFF0F111A),
                                style: const TextStyle(color: Colors.white),
                              ),
                    const SizedBox(height: 6),
                    Text(
                      c.content,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
