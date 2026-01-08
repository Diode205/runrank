import 'package:flutter/material.dart';
import 'package:runrank/services/malcolm_ball_award_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final nominees = await _service.fetchNominees();
      final comments = await _service.fetchRecentComments();
      if (!mounted) return;
      setState(() {
        _nominees = nominees;
        _comments = comments;
        _loading = false;
        _commentNomineeId = nominees.isNotEmpty ? nominees.first.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _commentController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomination submitted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nomination failed: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reacted $emoji')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reaction failed: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Malcolm Ball Award 2026'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroHeader(),
                    const SizedBox(height: 12),
                    _storyCard(),
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
    );
  }

  Widget _heroHeader() {
    return Stack(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: Image.asset(
            'assets/images/malcolmball.png',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.35),
            colorBlendMode: BlendMode.darken,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black54],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
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
    );
  }

  Widget _storyCard() {
    const story =
        'He has run across the mountainous Lake District terrain, completed 39 marathons, run for the England cross country team and gone through scores of trainers.\n\n'
        'An amateur running enthusiast Malcolm Ball, from Ridgeway in Cromer, has no plans to give up.\n'
        'Mr Ball, who served as a Royal Marines Commando for two years in Malaya as a teenager for his National Service, is a member of the North Norfolk Beach Runners.\n'
        'He has completed 80 Parkruns, mostly at Sheringham Park, but also at King\'s Lynn and Brighton.\n'
        'He won the amateur British Masters Athletics Federation 10 mile championships in the over 80s category in 97 minutes and nine seconds - nearly 28 minutes faster than the second place runner.\n'
        'His running accomplishments include completing the gruelling Lakeland Trails races across the Lake District when he was between 69 and 72-years-old and being called up twice for the England amateur cross country team.\n'
        'He has also completed eight marathons in under three hours.\n'
        'His fastest marathon time was two hours, 56 minutes and 49 seconds at London in 1990.\n'
        'As well as running 35-40 miles a week, Mr Ball goes to the gym every day and attends aqua Zumba and aqua fitness classes three times a week.\n'
        'He also trains newcomers to the North Norfolk Beach Runners.\n\n'
        '— Sophie Wyllie, Eastern Daily Press, 27 March 2015.  Picture: Mark Bullimore.  Image: Archant Norfolk 2015)';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5C542), width: 1),
        ),
        child: const Text(
          story,
          style: TextStyle(color: Colors.white, height: 1.35),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              decoration: const InputDecoration(
                labelText: 'Nominee full name',
              ),
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
                    (n) => DropdownMenuItem(
                      value: n.id,
                      child: Text(n.name),
                    ),
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
