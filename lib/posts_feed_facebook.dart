import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/widgets/inline_video_player.dart';
import 'package:runrank/admin/create_post_page.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/admin/edit_post_page.dart';
import 'package:runrank/widgets/linkified_text.dart';

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

  // Cache for reactions and comments to avoid redundant fetches
  final Map<String, Map<String, int>> _reactionCounts = {};
  final Map<String, Set<String>> _userReactionsByPost = {};
  final Map<String, List<Map<String, dynamic>>> _commentsByPost = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _showCommentInput = {};

  // Track which posts are currently fetching details to avoid duplicate calls
  final Set<String> _fetchingPostDetails = {};

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
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _checkAdminStatus();
    await _loadPosts();
    _setupRealtime();
  }

  @override
  void dispose() {
    _postChannel?.unsubscribe();
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setupRealtime() {
    // Only listen to the main post table for major changes (new posts/deletes)
    _postChannel = supabase
        .channel('public:club_posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_posts',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert ||
                payload.eventType == PostgresChangeEvent.delete) {
              _loadPosts();
            }
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
          .maybeSingle();
      if (mounted) {
        setState(() => isAdmin = profile?['is_admin'] ?? false);
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _loadPosts() async {
    try {
      final now = DateTime.now().toIso8601String();
      final user = supabase.auth.currentUser;

      final response = await supabase
          .from('club_posts')
          .select('''
            id, title, content, author_id, author_name, created_at, is_approved, expiry_date,
            user_profiles!club_posts_author_id_fkey(full_name, avatar_url, membership_type),
            club_post_attachments(*)
          ''')
          .gte('expiry_date', now)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          posts = List<Map<String, dynamic>>.from(response);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadPostDetails(String postId) async {
    if (_fetchingPostDetails.contains(postId)) return;
    _fetchingPostDetails.add(postId);

    try {
      await Future.wait([_loadReactions(postId), _loadComments(postId)]);
    } finally {
      _fetchingPostDetails.remove(postId);
    }
  }

  Future<void> _loadReactions(String postId) async {
    try {
      final user = supabase.auth.currentUser;
      final data = await supabase
          .from('club_post_reactions')
          .select('emoji, user_id')
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

      if (mounted) {
        setState(() {
          _reactionCounts[postId] = counts;
          _userReactionsByPost[postId] = userSet;
        });
      }
    } catch (e) {
      debugPrint('Error loading reactions: $e');
    }
  }

  Future<void> _loadComments(String postId) async {
    try {
      final data = await supabase
          .from('club_post_comments')
          .select('''
            id, user_id, comment, created_at,
            user_profiles!club_post_comments_user_id_fkey(full_name, avatar_url, membership_type)
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _commentsByPost[postId] = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
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

        // Notify the post author about the new reaction
        try {
          final post = posts.firstWhere(
            (p) => p['id'] == postId,
            orElse: () => {},
          );
          final authorId = post['author_id'] as String?;
          final title = post['title'] as String? ?? 'a post';

          if (authorId != null && authorId.isNotEmpty && authorId != user.id) {
            await NotificationService.notifyUser(
              userId: authorId,
              title: 'New reaction on your post',
              body: 'Someone reacted $emoji on "$title".',
            );
          }
        } catch (e) {
          debugPrint('Error sending post reaction notification: $e');
        }
      }
      _loadReactions(postId);
    } catch (e) {
      debugPrint('Reaction error: $e');
    }
  }

  Future<void> _addComment(String postId, String text) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (await UserService.isBlocked(context: context)) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      await supabase.from('club_post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'comment': trimmed,
      });
      _commentControllers[postId]?.clear();
      _loadComments(postId);

      // Notify the post author about the new comment
      try {
        final post = posts.firstWhere(
          (p) => p['id'] == postId,
          orElse: () => {},
        );
        final authorId = post['author_id'] as String?;
        final title = post['title'] as String? ?? 'a post';

        if (authorId != null && authorId.isNotEmpty && authorId != user.id) {
          await NotificationService.notifyUser(
            userId: authorId,
            title: 'New comment on your post',
            body: 'Someone commented on "$title".',
          );
        }
      } catch (e) {
        debugPrint('Error sending post comment notification: $e');
      }
    } catch (e) {
      debugPrint('Comment error: $e');
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

  Color _membershipColor(String? type) {
    switch (type) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Club Posts'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x4DFFD300), Color(0x4D0057B7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostPage()),
            ).then((_) => _loadPosts()),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPosts,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final postId = post['id'];

                  // Trigger details load only when item is built
                  if (!_reactionCounts.containsKey(postId)) {
                    _loadPostDetails(postId);
                  }

                  Widget card = _PostCard(
                    post: post,
                    isAdmin: isAdmin,
                    reactionCounts: _reactionCounts[postId] ?? {},
                    userReactions: _userReactionsByPost[postId] ?? {},
                    comments: _commentsByPost[postId] ?? [],
                    showCommentInput: _showCommentInput[postId] ?? false,
                    commentController: _commentControllers.putIfAbsent(
                      postId,
                      () => TextEditingController(),
                    ),
                    onToggleReaction: (emoji) => _toggleReaction(postId, emoji),
                    onCommentToggle: () => setState(
                      () => _showCommentInput[postId] =
                          !(_showCommentInput[postId] ?? false),
                    ),
                    onSendComment: (text) => _addComment(postId, text),
                    onApprove: () => _approvePost(postId),
                    onReject: () => _rejectPost(postId),
                    membershipColor: _membershipColor(
                      post['user_profiles']?['membership_type'],
                    ),
                    timeAgo: _getTimeAgo(post['created_at']),
                  );

                  if (isAdmin) {
                    return Dismissible(
                      key: ValueKey('post-fb-$postId'),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      secondaryBackground: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Edit post
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditPostPage(post: post),
                            ),
                          );
                          if (updated == true) {
                            await _loadPosts();
                          }
                          return false; // keep card on edit
                        }

                        // Delete confirmation
                        final shouldDelete =
                            await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete post?'),
                                content: const Text(
                                  'This will permanently delete the post.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (!shouldDelete) return false;

                        try {
                          await supabase
                              .from('club_posts')
                              .delete()
                              .eq('id', postId);
                          await _loadPosts();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post deleted')),
                            );
                          }
                          return true;
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting post: $e'),
                              ),
                            );
                          }
                          await _loadPosts();
                          return false;
                        }
                      },
                      child: card,
                    );
                  }

                  return card;
                },
              ),
            ),
    );
  }

  Future<void> _approvePost(String id) async {
    await supabase
        .from('club_posts')
        .update({'is_approved': true})
        .eq('id', id);
    _loadPosts();
  }

  Future<void> _rejectPost(String id) async {
    await supabase.from('club_posts').delete().eq('id', id);
    _loadPosts();
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isAdmin;
  final Map<String, int> reactionCounts;
  final Set<String> userReactions;
  final List<Map<String, dynamic>> comments;
  final bool showCommentInput;
  final TextEditingController commentController;
  final Function(String) onToggleReaction;
  final VoidCallback onCommentToggle;
  final Function(String) onSendComment;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final Color membershipColor;
  final String timeAgo;

  const _PostCard({
    required this.post,
    required this.isAdmin,
    required this.reactionCounts,
    required this.userReactions,
    required this.comments,
    required this.showCommentInput,
    required this.commentController,
    required this.onToggleReaction,
    required this.onCommentToggle,
    required this.onSendComment,
    required this.onApprove,
    required this.onReject,
    required this.membershipColor,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final profile = post['user_profiles'];
    final authorName =
        (profile?['full_name'] ?? post['author_name'] ?? 'Unknown').toString();
    final avatarUrl = profile?['avatar_url'] as String?;
    final attachments = (post['club_post_attachments'] as List?) ?? [];
    final totalReactions = reactionCounts.values.fold(0, (a, b) => a + b);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: membershipColor,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null ? Text(authorName[0]) : null,
            ),
            title: Text(
              authorName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(timeAgo),
            trailing: isAdmin && !(post['is_approved'] ?? false)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: onApprove,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: onReject,
                      ),
                    ],
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post['title'] != null)
                  Text(
                    post['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 8),
                LinkifiedText(text: post['content'] ?? ''),
              ],
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PostAttachments(attachments: attachments),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (totalReactions > 0)
                  Text(
                    '👍 $totalReactions',
                    style: const TextStyle(color: Colors.grey),
                  ),
                const Spacer(),
                if (comments.isNotEmpty)
                  Text(
                    '${comments.length} comments',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                icon: Icon(
                  userReactions.isNotEmpty
                      ? Icons.thumb_up
                      : Icons.thumb_up_outlined,
                ),
                label: const Text('Like'),
                onPressed: () => onToggleReaction('👍'),
              ),
              TextButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Comment'),
                onPressed: onCommentToggle,
              ),
            ],
          ),
          if (showCommentInput) ...[
            const Divider(),
            _CommentSection(
              comments: comments,
              controller: commentController,
              onSend: onSendComment,
            ),
          ],
        ],
      ),
    );
  }
}

class _PostAttachments extends StatelessWidget {
  final List attachments;
  const _PostAttachments({required this.attachments});

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a['type'] == 'image').toList();
    final links = attachments.where((a) => a['type'] == 'link').toList();
    final files = attachments.where((a) => a['type'] == 'file').toList();
    final videos = attachments.where((a) => a['type'] == 'video').toList();

    if (images.isEmpty && links.isEmpty && files.isEmpty && videos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              images.first['url'],
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: Colors.grey[800],
                child: Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        if (videos.isNotEmpty) ...[
          const SizedBox(height: 8),
          InlineVideoPlayer(url: videos.first['url'] as String),
        ],
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
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.image, size: 16),
                      label: Text(
                        a['name'] ?? 'Image',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ...links.map(
                (a) => ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.link, size: 16),
                  label: Text(
                    a['name'] ?? 'Link',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () async {
                    final url = a['url'] as String?;
                    if (url == null) return;
                    final uri = Uri.tryParse(url);
                    if (uri == null) return;
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
              ...videos
                  .skip(1)
                  .map(
                    (a) => ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.videocam, size: 16),
                      label: Text(
                        a['name'] ?? 'Video',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () async {
                        final url = a['url'] as String?;
                        if (url == null) return;
                        final uri = Uri.tryParse(url);
                        if (uri == null) return;
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ),
              ...files.map(
                (a) => ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.attachment, size: 16),
                  label: Text(
                    a['name'] ?? 'File',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () async {
                    final url = a['url'] as String?;
                    if (url == null) return;
                    final uri = Uri.tryParse(url);
                    if (uri == null) return;
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CommentSection extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  final TextEditingController controller;
  final Function(String) onSend;

  const _CommentSection({
    required this.comments,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...comments.map(
          (c) => ListTile(
            dense: true,
            title: Text(
              c['user_profiles']?['full_name'] ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(c['comment'] ?? ''),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => onSend(controller.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
