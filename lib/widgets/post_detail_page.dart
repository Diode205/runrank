import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/services/user_service.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final supabase = Supabase.instance.client;
  final _commentController = TextEditingController();
  Map<String, dynamic>? post;
  List<Map<String, dynamic>> comments = [];
  List<Map<String, dynamic>> attachments = [];
  Map<String, List<String>> reactions = {}; // emoji -> [user_ids]
  Set<String> userReactions = {}; // emojis the current user has used
  bool loading = true;
  bool isAdmin = false;
  bool isAuthor = false;
  bool isApproved = true;

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
    _loadPostDetails();
  }

  Future<void> _loadPostDetails() async {
    try {
      final user = supabase.auth.currentUser;

      // Load post with author info
      final postData = await supabase
          .from('club_posts')
          .select('''
            *,
            user_profiles!club_posts_author_id_fkey(full_name, avatar_url)
          ''')
          .eq('id', widget.postId)
          .maybeSingle();

      // Admin status
      Map<String, dynamic>? profile;
      if (user != null) {
        profile = await supabase
            .from('user_profiles')
            .select('is_admin')
            .eq('id', user.id)
            .maybeSingle();
      }

      // Load reactions
      final reactionsData = await supabase
          .from('club_post_reactions')
          .select()
          .eq('post_id', widget.postId);

      // Load comments with author names and avatars
      final commentsData = await supabase
          .from('club_post_comments')
          .select('''
            *,
            user_profiles!club_post_comments_user_id_fkey(full_name, avatar_url)
          ''')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      // Load attachments
      final attachmentsData = await supabase
          .from('club_post_attachments')
          .select()
          .eq('post_id', widget.postId)
          .order('created_at');

      // Group reactions by emoji
      final reactionMap = <String, List<String>>{};
      final userReactionSet = <String>{};

      for (final reaction in reactionsData) {
        final emoji = reaction['emoji'] as String;
        final userId = reaction['user_id'] as String;

        if (!reactionMap.containsKey(emoji)) {
          reactionMap[emoji] = [];
        }
        reactionMap[emoji]!.add(userId);

        if (user != null && userId == user.id) {
          userReactionSet.add(emoji);
        }
      }

      if (mounted) {
        setState(() {
          post = postData;
          comments = List<Map<String, dynamic>>.from(commentsData);
          attachments = List<Map<String, dynamic>>.from(attachmentsData);
          reactions = reactionMap;
          userReactions = userReactionSet;
          loading = false;
          isAdmin = (profile?['is_admin'] ?? false) as bool;
          isAuthor =
              user != null &&
              postData != null &&
              postData['author_id'] == user.id;
          isApproved = (postData?['is_approved'] ?? true) as bool;
        });
      }
    } catch (e) {
      print('Error loading post details: $e');
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _approvePost() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await supabase
          .from('club_posts')
          .update({
            'is_approved': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.postId);

      // Notify author
      final authorId = post?['author_id'] as String?;
      if (authorId != null) {
        await NotificationService.notifyUser(
          userId: authorId,
          title: 'Post Approved',
          body: 'Your post "${post?['title'] ?? 'Post'}" has been approved.',
        );
      }
      await _loadPostDetails();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Post approved')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectPost() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Keep as not approved, just notify author
      await supabase
          .from('club_posts')
          .update({
            'is_approved': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.postId);

      final authorId = post?['author_id'] as String?;
      if (authorId != null) {
        await NotificationService.notifyUser(
          userId: authorId,
          title: 'Post Not Approved',
          body:
              'Your post "${post?['title'] ?? 'Post'}" was not approved by an admin.',
        );
      }
      await _loadPostDetails();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Author notified: not approved')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editPost() async {
    if (post == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final titleController = TextEditingController(text: post!['title'] ?? '');
    final contentController = TextEditingController(
      text: post!['content'] ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Post'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 10,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await supabase
            .from('club_posts')
            .update({
              'title': titleController.text.trim(),
              'content': contentController.text.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.postId);
        await _loadPostDetails();
        if (mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('Post updated')));
        }
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deletePost() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'This will remove the post and all its comments and reactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await supabase.from('club_posts').delete().eq('id', widget.postId);
        if (mounted) navigator.pop();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleReaction(String emoji) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (userReactions.contains(emoji)) {
        // Remove reaction
        await supabase
            .from('club_post_reactions')
            .delete()
            .eq('post_id', widget.postId)
            .eq('user_id', user.id)
            .eq('emoji', emoji);
      } else {
        // Add reaction
        await supabase.from('club_post_reactions').insert({
          'post_id': widget.postId,
          'user_id': user.id,
          'emoji': emoji,
        });
      }
      _loadPostDetails(); // Refresh reactions
    } catch (e) {
      print('Error toggling reaction: $e');
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final user = supabase.auth.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) return;
    if (await UserService.isBlocked(context: context)) {
      return;
    }

    try {
      await supabase.from('club_post_comments').insert({
        'post_id': widget.postId,
        'user_id': user.id,
        'comment': _commentController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      _commentController.clear();
      _loadPostDetails(); // Refresh comments
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error posting comment: $e')),
      );
    }
  }

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()}mo ago';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0x4DFFD300), const Color(0x4D0057B7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (post == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Post Details'),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0x4DFFD300), const Color(0x4D0057B7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              const Text(
                'Post not found',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'This post may have been deleted',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final authorName = post!['user_profiles']?['full_name'] ?? 'Unknown';
    final authorAvatarUrl = post!['user_profiles']?['avatar_url'] as String?;
    final imageUrl = post!['image_url'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        actions: [
          if (isAdmin || isAuthor) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              onPressed: _editPost,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePost,
            ),
          ],
          if (isAdmin && !isApproved) ...[
            IconButton(
              tooltip: 'Approve',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: _approvePost,
            ),
            IconButton(
              tooltip: 'Reject',
              icon: const Icon(Icons.cancel_outlined),
              onPressed: _rejectPost,
            ),
          ],
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0x4DFFD300), const Color(0x4D0057B7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _getTimeAgo(post!['created_at']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      post!['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      post!['content'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[300],
                        height: 1.6,
                      ),
                    ),
                  ),

                  // Image
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
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
                  ],
                  // Attachments
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attachments',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: attachments.map((a) {
                              final attachType = a['type'] as String? ?? 'file';
                              final fileName =
                                  a['name'] as String? ?? 'Attachment';
                              final isImage = attachType == 'image';

                              IconData getIcon() {
                                if (isImage) return Icons.image;
                                if (fileName.toLowerCase().endsWith('.pdf')) {
                                  return Icons.picture_as_pdf;
                                }
                                if (fileName.toLowerCase().endsWith('.doc') ||
                                    fileName.toLowerCase().endsWith('.docx')) {
                                  return Icons.description;
                                }
                                if (fileName.toLowerCase().endsWith('.xls') ||
                                    fileName.toLowerCase().endsWith('.xlsx')) {
                                  return Icons.table_chart;
                                }
                                if (fileName.toLowerCase().endsWith('.ppt') ||
                                    fileName.toLowerCase().endsWith('.pptx')) {
                                  return Icons.slideshow;
                                }
                                if (fileName.toLowerCase().endsWith('.mp4') ||
                                    fileName.toLowerCase().endsWith('.mov') ||
                                    fileName.toLowerCase().endsWith('.avi') ||
                                    fileName.toLowerCase().endsWith('.mkv') ||
                                    fileName.toLowerCase().endsWith('.webm') ||
                                    fileName.toLowerCase().endsWith('.flv')) {
                                  return Icons.videocam;
                                }
                                if (fileName.toLowerCase().endsWith('.gif')) {
                                  return Icons.animation;
                                }
                                if (fileName.toLowerCase().endsWith('.zip') ||
                                    fileName.toLowerCase().endsWith('.rar') ||
                                    fileName.toLowerCase().endsWith('.7z')) {
                                  return Icons.folder_zip;
                                }
                                return Icons.attachment;
                              }

                              return ActionChip(
                                avatar: Icon(getIcon(), size: 18),
                                label: Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () async {
                                  final url = a['url'] as String?;
                                  if (url == null || url.isEmpty) return;
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    final uri = Uri.parse(url);
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Cannot open: $fileName'),
                                      ),
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Approval banner
                  if (!isApproved)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFD300),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x80FFD300)),
                        ),
                        child: const Text(
                          'Awaiting approval by an admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Emoji reactions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...availableEmojis.map((emoji) {
                            final count = reactions[emoji]?.length ?? 0;
                            final isSelected = userReactions.contains(emoji);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _toggleReaction(emoji),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.withValues(alpha: 0.3)
                                        : Colors.grey[800],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey[700]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      if (count > 0) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '$count',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[400],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 32),

                  // Kudos button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _toggleReaction('❤️'),
                          icon: Icon(
                            userReactions.contains('❤️')
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: userReactions.contains('❤️')
                                ? Colors.red
                                : Colors.grey[400],
                            size: 28,
                          ),
                        ),
                        Text(
                          '${reactions['❤️']?.length ?? 0} ${(reactions['❤️']?.length ?? 0) == 1 ? 'Like' : 'Likes'}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 32),

                  // Comments section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Comments (${comments.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comments list
                  ...comments.map((comment) {
                    final commentAuthor =
                        comment['user_profiles']?['full_name'] ?? 'Unknown';
                    final avatarUrl =
                        comment['user_profiles']?['avatar_url'] as String?;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.green,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(
                                    '$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                                  )
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    commentAuthor[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      commentAuthor,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getTimeAgo(comment['created_at']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment['comment'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[300],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        filled: true,
                        fillColor: Colors.grey[850],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFD300), Color(0xFF0057B7)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _postComment,
                      icon: const Icon(Icons.send, color: Colors.white),
                      iconSize: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
