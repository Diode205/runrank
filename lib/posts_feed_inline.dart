import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/admin/create_post_page.dart';
import 'package:runrank/services/user_service.dart';

class PostsFeedInlineScreen extends StatefulWidget {
  const PostsFeedInlineScreen({super.key});

  @override
  State<PostsFeedInlineScreen> createState() => _PostsFeedInlineScreenState();
}

class _PostsFeedInlineScreenState extends State<PostsFeedInlineScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  bool isAdmin = false;

  // Track expanded states per post
  final Map<String, bool> _expandedReactions = {};
  final Map<String, bool> _expandedComments = {};
  final Map<String, TextEditingController> _commentControllers = {};
  // Inline data caches
  final Map<String, Map<String, int>> _reactionCounts =
      {}; // postId -> emoji -> count
  final Map<String, Set<String>> _userReactionsByPost =
      {}; // postId -> emojis reacted by current user
  final Map<String, List<Map<String, dynamic>>> _commentsByPost =
      {}; // postId -> comments list

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
  }

  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
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

      if (mounted) {
        setState(() => isAdmin = profile['is_admin'] ?? false);
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
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
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in to react')));
      return;
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reaction error: $e')));
    }
  }

  Future<void> _loadComments(String postId) async {
    try {
      final data = await supabase
          .from('club_post_comments')
          .select('''
            id, user_id, comment, created_at,
            user_profiles!club_post_comments_user_id_fkey(full_name, avatar_url)
          ''')
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
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }
    if (await UserService.isBlocked(context: context)) {
      return;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await supabase.from('club_post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'comment': trimmed,
      });
      _commentControllers[postId]?.clear();
      await _loadComments(postId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Comment error: $e')));
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
              '*, user_profiles!club_posts_author_id_fkey(full_name, avatar_url), club_post_attachments(*)',
            )
            .gte('expiry_date', now)
            .order('created_at', ascending: false);
      } else if (user != null) {
        final approved = await supabase
            .from('club_posts')
            .select(
              '*, user_profiles!club_posts_author_id_fkey(full_name, avatar_url), club_post_attachments(*)',
            )
            .gte('expiry_date', now)
            .eq('is_approved', true)
            .order('created_at', ascending: false);

        final mine = await supabase
            .from('club_posts')
            .select(
              '*, user_profiles!club_posts_author_id_fkey(full_name, avatar_url), club_post_attachments(*)',
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
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _approvePost(String postId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await supabase
          .from('club_posts')
          .update({
            'is_approved': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', postId);
      await _loadPosts();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Post approved')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectPost(String postId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await supabase.from('club_posts').delete().eq('id', postId);
      await _loadPosts();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Post rejected')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
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

  Future<void> _openAttachmentUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Best effort; ignore failures here
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
                  final authorAvatarUrl =
                      post['user_profiles']?['avatar_url'] as String?;
                  final attachments =
                      (post['club_post_attachments'] as List?)
                          ?.map((e) => e as Map<String, dynamic>)
                          .toList() ??
                      [];
                  final timeAgo = _getTimeAgo(post['created_at']);
                  final isApproved = post['is_approved'] ?? true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.grey[850],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.blue,
                                backgroundImage: authorAvatarUrl != null
                                    ? NetworkImage(
                                        '$authorAvatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                                      )
                                    : null,
                                child: authorAvatarUrl == null
                                    ? Text(
                                        authorName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
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
                                    tooltip: 'Approve',
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
                                    tooltip: 'Reject',
                                  ),
                                ],
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
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

                          // Attachments
                          if (attachments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final images = attachments
                                    .where((a) => a['type'] == 'image')
                                    .toList();
                                final links = attachments
                                    .where((a) => a['type'] == 'link')
                                    .toList();
                                final files = attachments
                                    .where((a) => a['type'] == 'file')
                                    .toList();
                                final videos = attachments
                                    .where((a) => a['type'] == 'video')
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
                                            12,
                                          ),
                                          child: Image.network(
                                            images.first['url'],
                                            width: double.infinity,
                                            height: 180,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  height: 180,
                                                  color: Colors.grey[800],
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    size: 48,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    if (images.length > 1 ||
                                        links.isNotEmpty ||
                                        files.isNotEmpty ||
                                        videos.isNotEmpty) ...[
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
                                            (a) => ActionChip(
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
                                              onPressed: () =>
                                                  _openAttachmentUrl(
                                                    a['url'] as String?,
                                                  ),
                                            ),
                                          ),
                                          ...videos.map(
                                            (a) => ActionChip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              avatar: const Icon(
                                                Icons.videocam,
                                                size: 16,
                                              ),
                                              label: Text(
                                                a['name'] ?? 'Video',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _openAttachmentUrl(
                                                    a['url'] as String?,
                                                  ),
                                            ),
                                          ),
                                          ...files.map(
                                            (a) => ActionChip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              avatar: const Icon(
                                                Icons.attachment,
                                                size: 16,
                                              ),
                                              label: Text(
                                                a['name'] ?? 'File',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _openAttachmentUrl(
                                                    a['url'] as String?,
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
                          ],

                          // Footer with reactions/comments
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  setState(() {
                                    _expandedReactions[postId] =
                                        !(_expandedReactions[postId] ?? false);
                                  });
                                  if (_expandedReactions[postId] == true) {
                                    await _loadReactions(postId);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey[700]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '👍',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _expandedReactions[postId] == true
                                            ? Icons.expand_less
                                            : Icons.add,
                                        size: 14,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () async {
                                  setState(() {
                                    _expandedComments[postId] =
                                        !(_expandedComments[postId] ?? false);
                                    if (_expandedComments[postId] == true &&
                                        !_commentControllers.containsKey(
                                          postId,
                                        )) {
                                      _commentControllers[postId] =
                                          TextEditingController();
                                    }
                                  });
                                  if (_expandedComments[postId] == true) {
                                    await _loadComments(postId);
                                  }
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.comment_outlined,
                                      size: 18,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Comment',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Expanded reactions
                          if (_expandedReactions[postId] == true) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: availableEmojis.map((emoji) {
                                final counts =
                                    _reactionCounts[postId] ?? const {};
                                final count = counts[emoji] ?? 0;
                                final selected =
                                    _userReactionsByPost[postId]?.contains(
                                      emoji,
                                    ) ??
                                    false;
                                return GestureDetector(
                                  onTap: () => _toggleReaction(postId, emoji),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.blue.withValues(alpha: 0.3)
                                          : Colors.grey[800],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected
                                            ? Colors.blue
                                            : Colors.grey[700]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$count',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[300],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],

                          // Expanded comments
                          if (_expandedComments[postId] == true) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Comments',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if ((_commentsByPost[postId] ?? const [])
                                      .isEmpty)
                                    Text(
                                      'No comments yet',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    )
                                  else
                                    Column(
                                      children: (_commentsByPost[postId] ?? const []).map((
                                        c,
                                      ) {
                                        final commentAuthor =
                                            c['user_profiles']?['full_name'] ??
                                            'Unknown';
                                        final commentAvatarUrl =
                                            c['user_profiles']?['avatar_url']
                                                as String?;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor:
                                                    Colors.grey[700],
                                                backgroundImage:
                                                    commentAvatarUrl != null
                                                    ? NetworkImage(
                                                        '$commentAvatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                                                      )
                                                    : null,
                                                child: commentAvatarUrl == null
                                                    ? Text(
                                                        commentAuthor[0]
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          fontSize: 8,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      commentAuthor,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    Text(
                                                      c['comment'] ?? '',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    Text(
                                                      c['created_at']
                                                              ?.toString() ??
                                                          '',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              _commentControllers[postId],
                                          decoration: InputDecoration(
                                            hintText: 'Add a comment...',
                                            hintStyle: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                          final text =
                                              _commentControllers[postId]
                                                  ?.text ??
                                              '';
                                          _addComment(postId, text);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
