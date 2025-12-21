import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/admin/create_post_page.dart';

class PostsFeedFacebookScreen extends StatefulWidget {
  const PostsFeedFacebookScreen({super.key});

  @override
  State<PostsFeedFacebookScreen> createState() =>
      _PostsFeedFacebookScreenState();
}

class _PostsFeedFacebookScreenState extends State<PostsFeedFacebookScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  bool isAdmin = false;

  RealtimeChannel? _postChannel;
  RealtimeChannel? _reactionChannel;
  RealtimeChannel? _commentChannel;

  // Per-post caches
  final Map<String, Map<String, int>> _reactionCounts = {};
  final Map<String, Set<String>> _userReactionsByPost = {};
  final Map<String, List<Map<String, dynamic>>> _commentsByPost = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _showCommentInput = {};

  static const List<String> availableEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '😡',
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadPosts();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_postChannel != null) {
      supabase.removeChannel(_postChannel!);
    }
    if (_reactionChannel != null) {
      supabase.removeChannel(_reactionChannel!);
    }
    if (_commentChannel != null) {
      supabase.removeChannel(_commentChannel!);
    }
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setupRealtime() {
    // Posts changes
    _postChannel = supabase
        .channel('realtime-posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_posts',
          callback: (payload) {
            _loadPosts();
          },
        )
        .subscribe();

    // Reactions changes
    _reactionChannel = supabase
        .channel('realtime-reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_post_reactions',
          callback: (payload) {
            final postId = payload.newRecord['post_id'] as String?;
            if (postId != null) _loadReactions(postId);
          },
        )
        .subscribe();

    // Comments changes
    _commentChannel = supabase
        .channel('realtime-comments')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_post_comments',
          callback: (payload) {
            final postId = payload.newRecord['post_id'] as String?;
            if (postId != null) _loadComments(postId);
          },
        )
        .subscribe();
  }

  Future<void> _checkAdminStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await supabase
          .from('user_profiles')
          .select('is_admin')
          .eq('id', user.id)
          .single();
      if (mounted) setState(() => isAdmin = profile['is_admin'] ?? false);
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  Future<void> _loadPosts() async {
    try {
      final now = DateTime.now().toIso8601String();
      final user = supabase.auth.currentUser;

      List data;
      if (isAdmin) {
        data = await supabase
            .from('club_posts')
            .select(
              '*, user_profiles!club_posts_author_id_fkey(full_name), club_post_attachments(*)',
            )
            .gte('expiry_date', now)
            .order('created_at', ascending: false);
      } else if (user != null) {
        final approved = await supabase
            .from('club_posts')
            .select(
              '*, user_profiles!club_posts_author_id_fkey(full_name), club_post_attachments(*)',
            )
            .gte('expiry_date', now)
            .eq('is_approved', true)
            .order('created_at', ascending: false);

        final mine = await supabase
            .from('club_posts')
            .select(
              '*, user_profiles!club_posts_author_id_fkey(full_name), club_post_attachments(*)',
            )
            .gte('expiry_date', now)
            .eq('author_id', user.id)
            .order('created_at', ascending: false);

        final seen = <String>{};
        data = [];
        for (final row in approved) {
          if (seen.add(row['id'] as String)) data.add(row);
        }
        for (final row in mine) {
          if (seen.add(row['id'] as String)) data.add(row);
        }
        data.sort(
          (a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String),
        );
      } else {
        data = [];
      }

      if (mounted) {
        setState(() {
          posts = List<Map<String, dynamic>>.from(data);
          loading = false;
        });
      }
    } catch (e) {
      print('Error loading posts: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _approvePost(String postId) async {
    try {
      await supabase
          .from('club_posts')
          .update({
            'is_approved': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', postId);
      await _loadPosts();
    } catch (e) {
      print('Approve error: $e');
    }
  }

  Future<void> _rejectPost(String postId) async {
    try {
      await supabase.from('club_posts').delete().eq('id', postId);
      await _loadPosts();
    } catch (e) {
      print('Reject error: $e');
    }
  }

  void _openImageFullscreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadReactions(String postId) async {
    try {
      final user = supabase.auth.currentUser;
      final data = await supabase
          .from('club_post_reactions')
          .select('post_id, user_id, emoji')
          .eq('post_id', postId);

      final counts = <String, int>{};
      final userSet = <String>{};
      for (final row in data) {
        final emoji = row['emoji'] as String;
        counts[emoji] = (counts[emoji] ?? 0) + 1;
        if (user != null && row['user_id'] == user.id) {
          userSet.add(emoji);
        }
      }

      setState(() {
        _reactionCounts[postId] = counts;
        _userReactionsByPost[postId] = userSet;
      });
    } catch (e) {
      print('Error loading reactions: $e');
    }
  }

  Future<void> _toggleReaction(String postId, String emoji) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final hasReacted = _userReactionsByPost[postId]?.contains(emoji) ?? false;
      if (hasReacted) {
        await supabase
            .from('club_post_reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id)
            .eq('emoji', emoji);
      } else {
        await supabase.from('club_post_reactions').insert({
          'post_id': postId,
          'user_id': user.id,
          'emoji': emoji,
        });
      }
      await _loadReactions(postId);
    } catch (e) {
      print('Reaction error: $e');
    }
  }

  Future<void> _loadComments(String postId) async {
    try {
      final data = await supabase
          .from('club_post_comments')
          .select('id, user_id, comment, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      setState(() {
        _commentsByPost[postId] = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _addComment(String postId, String text) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await supabase.from('club_post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'comment': trimmed,
      });
      _commentControllers[postId]?.clear();
      // Keep comment input visible after posting
      setState(() {
        _showCommentInput[postId] = true;
      });
      await _loadComments(postId);
    } catch (e) {
      print('Comment error: $e');
    }
  }

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Club Posts'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0x4DFFD300), const Color(0x4D0057B7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostPage()),
              );
              _loadPosts();
            },
            tooltip: 'Create Post',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back for updates from the club',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPosts,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final postId = post['id'] as String;
                  final authorName =
                      post['user_profiles']?['full_name'] ?? 'Unknown';
                  final attachments =
                      (post['club_post_attachments'] as List?)
                          ?.map((e) => e as Map<String, dynamic>)
                          .toList() ??
                      [];
                  final timeAgo = _getTimeAgo(post['created_at']);
                  final isApproved = post['is_approved'] ?? true;

                  // Ensure data is loaded for this post
                  if (!_reactionCounts.containsKey(postId)) {
                    _reactionCounts[postId] = {};
                    _userReactionsByPost[postId] = {};
                    _loadReactions(postId);
                  }
                  if (!_commentsByPost.containsKey(postId)) {
                    _commentsByPost[postId] = [];
                    _loadComments(postId);
                  }
                  if (!_commentControllers.containsKey(postId)) {
                    _commentControllers[postId] = TextEditingController();
                  }

                  final totalReactions = (_reactionCounts[postId] ?? const {})
                      .values
                      .fold(0, (a, b) => a + b);
                  final commentCount =
                      (_commentsByPost[postId] ?? const []).length;
                  final reactionEmojis = (_reactionCounts[postId] ?? const {})
                      .keys
                      .toList()
                      .take(3)
                      .toList();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.grey[850],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.blue,
                                child: Text(
                                  authorName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      authorName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      timeAgo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isApproved) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33FFD300),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0x80FFD300),
                                    ),
                                  ),
                                  child: const Text(
                                    'Pending',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _approvePost(postId),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _rejectPost(postId),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),

                        // Title + Content
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['title'] ?? '',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                post['content'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[300],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Attachments
                        if (attachments.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Builder(
                              builder: (context) {
                                final images = attachments
                                    .where((a) => a['type'] == 'image')
                                    .toList();
                                final links = attachments
                                    .where((a) => a['type'] == 'link')
                                    .toList();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (images.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => _openImageFullscreen(
                                          images.first['url'],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            images.first['url'],
                                            width: double.infinity,
                                            height: 200,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    if (images.length > 1 ||
                                        links.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          ...images
                                              .skip(1)
                                              .map(
                                                (a) => Chip(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  avatar: const Icon(
                                                    Icons.image,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    a['name'] ?? 'Image',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ...links.map(
                                            (a) => Chip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              avatar: const Icon(
                                                Icons.link,
                                                size: 16,
                                              ),
                                              label: Text(
                                                a['name'] ?? 'Link',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ],

                        // Reactions + Comments count (Facebook-style)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              if (totalReactions > 0) ...[
                                Row(
                                  children: [
                                    ...reactionEmojis.map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 2,
                                        ),
                                        child: Text(
                                          e,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$totalReactions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const Spacer(),
                              if (commentCount > 0)
                                Text(
                                  '$commentCount comments',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Divider
                        Divider(
                          color: Colors.grey[800],
                          height: 1,
                          thickness: 0.5,
                        ),

                        // Action buttons (Like, Comment, Share)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Like (expand emojis)
                              _buildActionButton(
                                icon: Icons.thumb_up_outlined,
                                label: 'Like',
                                onTap: () async {
                                  await showModalBottomSheet(
                                    context: context,
                                    builder: (_) => Container(
                                      color: Colors.grey[900],
                                      padding: const EdgeInsets.all(16),
                                      child: Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: availableEmojis
                                            .map(
                                              (emoji) => GestureDetector(
                                                onTap: () {
                                                  _toggleReaction(
                                                    postId,
                                                    emoji,
                                                  );
                                                  Navigator.pop(context);
                                                },
                                                child: Text(
                                                  emoji,
                                                  style: const TextStyle(
                                                    fontSize: 32,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Comment
                              _buildActionButton(
                                icon: Icons.chat_bubble_outline,
                                label: 'Comment',
                                onTap: () {
                                  setState(() {
                                    _showCommentInput[postId] =
                                        !(_showCommentInput[postId] ?? false);
                                  });
                                },
                              ),
                              // Share
                              _buildActionButton(
                                icon: Icons.share_outlined,
                                label: 'Share',
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),

                        // Comments section
                        if ((_commentsByPost[postId] ?? const [])
                            .isNotEmpty) ...[
                          Divider(
                            color: Colors.grey[800],
                            height: 1,
                            thickness: 0.5,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: (_commentsByPost[postId] ?? const [])
                                  .map(
                                    (c) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.blue,
                                            child: const Icon(
                                              Icons.person,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[800],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c['comment'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _getTimeAgo(
                                                      c['created_at']
                                                          ?.toString(),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
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

                        // Comment input (always visible if toggled)
                        if (_showCommentInput[postId] == true) ...[
                          Divider(
                            color: Colors.grey[800],
                            height: 1,
                            thickness: 0.5,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue,
                                  child: const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _commentControllers[postId],
                                    decoration: InputDecoration(
                                      hintText: 'Write a comment...',
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide(
                                          color: Colors.grey[700]!,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.send,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    _addComment(
                                      postId,
                                      _commentControllers[postId]?.text ?? '',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
