import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/widgets/inline_video_player.dart';
import 'package:runrank/admin/create_post_page.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/admin/edit_post_page.dart';
import 'package:runrank/widgets/linkified_text.dart';
import 'package:runrank/widgets/post_detail_page.dart';
import 'package:runrank/widgets/web_link_preview_card.dart';
import 'dart:async';

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

  String? _clubName;

  RealtimeChannel? _postChannel;
  RealtimeChannel? _postReactionsChannel;
  RealtimeChannel? _postCommentsChannel;
  Timer? _refreshTimer;

  // Cache for reactions and comments to avoid redundant fetches
  final Map<String, Map<String, int>> _reactionCounts = {};
  final Map<String, Set<String>> _userReactionsByPost = {};
  final Map<String, List<Map<String, dynamic>>> _commentsByPost = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _showCommentInput = {};

  // Track which posts are currently fetching details to avoid duplicate calls
  final Set<String> _fetchingPostDetails = {};

  // Emoji palette for reactions (kept for reference by reaction UI)
  // ignore: unused_field
  static const List<String> _availableEmojis = [
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
    _setupRealtime();
    _setupFallbackRefresh();
    _initPosts();
  }

  Future<void> _initPosts() async {
    await _checkAdminStatus();
    await _loadPosts();
  }

  void _setupRealtime() {
    // Listen for changes to club_posts so the feed stays up to date
    // for new posts, deletions, and approvals.
    _postChannel = supabase
        .channel('public:club_posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_posts',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert ||
                payload.eventType == PostgresChangeEvent.delete ||
                payload.eventType == PostgresChangeEvent.update) {
              _loadPosts();
            }
          },
        )
        .subscribe();

    _postReactionsChannel = supabase
        .channel('public:club_post_reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_post_reactions',
          callback: (payload) {
            final postId =
                payload.newRecord['post_id']?.toString() ??
                payload.oldRecord['post_id']?.toString();
            if (postId != null && postId.isNotEmpty) {
              _loadReactions(postId);
            }
          },
        )
        .subscribe();

    _postCommentsChannel = supabase
        .channel('public:club_post_comments')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_post_comments',
          callback: (payload) {
            final postId =
                payload.newRecord['post_id']?.toString() ??
                payload.oldRecord['post_id']?.toString();
            if (postId != null && postId.isNotEmpty) {
              _loadComments(postId);
            }
          },
        )
        .subscribe();
  }

  void _setupFallbackRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      _loadPosts();
    });
  }

  @override
  void dispose() {
    _postChannel?.unsubscribe();
    _postReactionsChannel?.unsubscribe();
    _postCommentsChannel?.unsubscribe();
    _refreshTimer?.cancel();
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
          .select('is_admin, club')
          .eq('id', user.id)
          .maybeSingle();

      final adminStatus = profile?['is_admin'] ?? false;
      final clubNameRaw = (profile?['club'] as String?)?.trim();
      final clubName = (clubNameRaw != null && clubNameRaw.isNotEmpty)
          ? clubNameRaw
          : null;

      if (mounted) {
        setState(() {
          isAdmin = adminStatus;
          _clubName = clubName;
        });
      }
      UserService.cacheClubName(clubName);
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<Set<String>?> _resolveCurrentClubUserIds() async {
    final clubName = _clubName ?? UserService.cachedClubName;
    if (clubName == null || clubName.trim().isEmpty) {
      return null;
    }

    try {
      final ids = await NotificationService.userIdsForClub(clubName);
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        ids.add(currentUserId);
      }
      return ids.isEmpty ? null : ids;
    } catch (e) {
      debugPrint('PostsFeedFacebook: error loading club user ids: $e');
      return null;
    }
  }

  Future<void> _loadPosts() async {
    try {
      final now = DateTime.now().toIso8601String();
      final user = supabase.auth.currentUser;

      final clubUserIds = await _resolveCurrentClubUserIds();
      if (clubUserIds == null || clubUserIds.isEmpty) {
        if (mounted) {
          setState(() {
            posts = [];
            loading = false;
          });
        }
        return;
      }

      var query = supabase
          .from('club_posts')
          .select('''
            id, title, content, author_id, author_name, created_at, is_approved, expiry_date,
            user_profiles!club_posts_author_id_fkey(full_name, avatar_url, membership_type),
            club_post_attachments(*)
          ''')
          .gte('expiry_date', now);

      if (!isAdmin) {
        query = query
            .eq('is_approved', true)
            .inFilter('author_id', clubUserIds.toList());
      } else {
        query = query.inFilter('author_id', clubUserIds.toList());
      }

      final response = await query.order('created_at', ascending: false);

      List data;

      if (!isAdmin && user != null) {
        // For non-admins, also include their own pending posts in a
        // distinct section (only visible to them).
        final pending = await supabase
            .from('club_posts')
            .select('''
              id, title, content, author_id, author_name, created_at, is_approved, expiry_date,
              user_profiles!club_posts_author_id_fkey(full_name, avatar_url, membership_type),
              club_post_attachments(*)
            ''')
            .gte('expiry_date', now)
            .eq('author_id', user.id)
            .eq('is_approved', false)
            .order('created_at', ascending: false);

        final seenIds = <String>{};
        final combined = <Map<String, dynamic>>[];

        for (final row in pending as List) {
          final id = row['id'] as String?;
          if (id == null) continue;
          if (seenIds.add(id)) {
            row['__pending'] = true;
            combined.add(row as Map<String, dynamic>);
          }
        }

        for (final row in response as List) {
          final id = row['id'] as String?;
          if (id == null) continue;
          if (seenIds.add(id)) {
            combined.add(row as Map<String, dynamic>);
          }
        }

        data = combined;
      } else {
        data = response as List;
      }

      if (mounted) {
        setState(() {
          posts = List<Map<String, dynamic>>.from(data);
          loading = false;
        });
      }

      final postIds = data
          .map((row) => row['id'] as String?)
          .whereType<String>()
          .toList();
      if (postIds.isNotEmpty) {
        await Future.wait(postIds.map(_loadPostDetails));
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
              route: 'post_$postId',
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
            route: 'post_$postId',
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
    final brandColors = UserService.clubBrandGradient(_clubName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Club Posts'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: brandColors,
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
                key: const PageStorageKey<String>('posts_feed_facebook_scroll'),
                padding: const EdgeInsets.all(12),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final postId = post['id'];
                  final isPending = post['__pending'] == true;

                  // Trigger details load only when item is built
                  if (!_reactionCounts.containsKey(postId)) {
                    _loadPostDetails(postId);
                  }

                  Widget card = _PostCard(
                    key: ValueKey('post-card-$postId'),
                    post: post,
                    isAdmin: isAdmin,
                    isPending: isPending,
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
                    onOpenDetail: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(
                            postId: postId,
                            initialClubName: _clubName,
                          ),
                        ),
                      );
                    },
                  );

                  // Allow admins and authors to swipe to edit/delete
                  final currentUser = supabase.auth.currentUser;
                  final isAuthor =
                      currentUser != null &&
                      post['author_id'] == currentUser.id;
                  final canModify = isAdmin || isAuthor;

                  if (canModify) {
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
                          // Edit post (admin or author)
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

                  // For non-admin, non-author viewers, optionally show a
                  // heading before the first pending post in their list.
                  if (!isAdmin && isPending) {
                    final bool isFirstPending =
                        index == 0 || posts[index - 1]['__pending'] != true;
                    if (isFirstPending) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                            child: Text(
                              'Pending posts (only visible to you)',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          card,
                        ],
                      );
                    }
                  }

                  return card;
                },
              ),
            ),
    );
  }

  Future<void> _approvePost(String id) async {
    final post = await supabase
        .from('club_posts')
        .select('author_id, title')
        .eq('id', id)
        .maybeSingle();

    await supabase
        .from('club_posts')
        .update({'is_approved': true})
        .eq('id', id);

    final authorId = post?['author_id'] as String?;
    final title = (post?['title'] ?? 'Post').toString();
    if (authorId != null) {
      await NotificationService.notifyUser(
        userId: authorId,
        title: 'Post Approved',
        body:
            'Your post "$title" has been approved and is now visible to club members.',
        route: 'posts',
      );
    }

    await _loadPosts();
  }

  Future<void> _rejectPost(String id) async {
    // Ask admin for a rejection reason before deleting/notifying.
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deny Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for denying this post:'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Reason for denial',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Deny'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final reason = reasonController.text.trim();

    // Fetch author and title prior to delete so we can notify.
    final post = await supabase
        .from('club_posts')
        .select('author_id, title')
        .eq('id', id)
        .maybeSingle();

    await supabase.from('club_posts').delete().eq('id', id);

    final authorId = post?['author_id'] as String?;
    final title = (post?['title'] ?? 'Post').toString();
    if (authorId != null) {
      final reasonText = reason.isNotEmpty ? ' Reason: $reason' : '';
      await NotificationService.notifyUser(
        userId: authorId,
        title: 'Post Not Approved',
        body:
            'Your post "$title" was not approved by an admin as it does not meet the Club\'s Privacy and Data Protection Policies.$reasonText Please see Policies, Forms, and Notices in the Menu for full details.',
        route: 'policies',
      );
    }

    _loadPosts();
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isAdmin;
  final bool isPending;
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
  final VoidCallback onOpenDetail;

  const _PostCard({
    super.key,
    required this.post,
    required this.isAdmin,
    required this.isPending,
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
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final profile = post['user_profiles'];
    final authorName =
        (profile?['full_name'] ?? post['author_name'] ?? 'Unknown').toString();
    final avatarUrl = profile?['avatar_url'] as String?;
    final attachments = (post['club_post_attachments'] as List?) ?? [];
    final contentPreviewUrl = WebLinkPreviewCard.extractFirstUrl(
      post['content'] as String?,
    );
    final displayContent = WebLinkPreviewCard.removeFirstUrl(
      post['content'] as String?,
    );
    final reactionCount = reactionCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );

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
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Approve'),
                        onPressed: onApprove,
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Deny'),
                        onPressed: onReject,
                      ),
                    ],
                  )
                : null,
          ),
          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                isAdmin
                    ? 'Pending approval'
                    : 'Pending approval (only visible to you)',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                if (displayContent.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LinkifiedText(text: displayContent),
                ],
              ],
            ),
          ),
          if (attachments.isNotEmpty || contentPreviewUrl != null) ...[
            const SizedBox(height: 12),
            _PostAttachments(
              attachments: attachments,
              content: post['content'] as String?,
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                TextButton.icon(
                  icon: Icon(
                    userReactions.contains('❤️')
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    color: userReactions.contains('❤️')
                        ? Colors.blue
                        : Colors.grey,
                    size: 20,
                  ),
                  label: Text('Like ($reactionCount)'),
                  onPressed: () => onToggleReaction('❤️'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onOpenDetail,
                  child: Text('Comments (${comments.length})'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostAttachments extends StatelessWidget {
  final List attachments;
  final String? content;
  const _PostAttachments({required this.attachments, this.content});

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a['type'] == 'image').toList();
    final links = attachments.where((a) => a['type'] == 'link').toList();
    final files = attachments.where((a) => a['type'] == 'file').toList();
    final videos = attachments.where((a) => a['type'] == 'video').toList();
    final contentPreviewUrl = WebLinkPreviewCard.extractFirstUrl(content);
    final firstPreviewUrl = links.isNotEmpty
        ? links.first['url'] as String?
        : contentPreviewUrl;
    final hasInlinePreview =
        firstPreviewUrl != null && firstPreviewUrl.isNotEmpty;

    if (images.isEmpty &&
        links.isEmpty &&
        files.isEmpty &&
        videos.isEmpty &&
        !hasInlinePreview) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) _ImageCollagePreview(images: images),
        if (videos.isNotEmpty) ...[
          const SizedBox(height: 8),
          InlineVideoPlayer(url: videos.first['url'] as String),
        ],
        if (hasInlinePreview) ...[
          const SizedBox(height: 8),
          WebLinkPreviewCard(
            url: firstPreviewUrl,
            buttonLabel: 'View Full Page',
            height: 460,
          ),
        ],
        if (links
                .skip(hasInlinePreview && links.isNotEmpty ? 1 : 0)
                .isNotEmpty ||
            files.isNotEmpty ||
            videos.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...links
                  .skip(hasInlinePreview && links.isNotEmpty ? 1 : 0)
                  .map(
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

class _ImageCollagePreview extends StatelessWidget {
  final List images;

  const _ImageCollagePreview({required this.images});

  @override
  Widget build(BuildContext context) {
    final visibleImages = images.take(3).toList();

    if (visibleImages.length == 1) {
      return _CollageImageTile(
        url: visibleImages.first['url'] as String?,
        height: 300,
        fit: BoxFit.contain,
        backgroundColor: Colors.black,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 240,
        child: visibleImages.length == 2
            ? Row(
                children: [
                  Expanded(
                    child: _CollageImageTile(
                      url: visibleImages[0]['url'] as String?,
                      height: double.infinity,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _CollageImageTile(
                      url: visibleImages[1]['url'] as String?,
                      height: double.infinity,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _CollageImageTile(
                      url: visibleImages[0]['url'] as String?,
                      height: double.infinity,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _CollageImageTile(
                            url: visibleImages[1]['url'] as String?,
                            height: double.infinity,
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _CollageImageTile(
                                url: visibleImages[2]['url'] as String?,
                                height: double.infinity,
                                borderRadius: BorderRadius.zero,
                              ),
                              if (images.length > visibleImages.length)
                                Container(
                                  color: Colors.black54,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+${images.length - visibleImages.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CollageImageTile extends StatelessWidget {
  final String? url;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Color? backgroundColor;

  const _CollageImageTile({
    required this.url,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.fit = BoxFit.cover,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        color: backgroundColor,
        width: double.infinity,
        height: height,
        child: Image.network(
          url ?? '',
          fit: fit,
          width: double.infinity,
          height: height,
          errorBuilder: (_, __, ___) => Container(
            height: height,
            color: Colors.grey[800],
            child: Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}
