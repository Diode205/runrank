import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/widgets/post_detail_page.dart';
import 'package:runrank/admin/create_post_page.dart';

class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({super.key});

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  bool isAdmin = false;
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

  @override
  void initState() {
    super.initState();
    debugPrint('PostsFeed: initState called');
    _checkAdminStatus().then((_) {
      debugPrint('PostsFeed: Admin check complete, loading posts...');
      _loadPosts();
    });
  }

  Future<void> _checkAdminStatus() async {
    final user = supabase.auth.currentUser;
    debugPrint('PostsFeed: _checkAdminStatus called, user: ${user?.id}');
    if (user == null) {
      debugPrint('PostsFeed: No user found, cannot check admin');
      return;
    }

    try {
      final profile = await supabase
          .from('user_profiles')
          .select('is_admin')
          .eq('id', user.id)
          .single();

      final adminStatus = profile['is_admin'] ?? false;
      debugPrint('PostsFeed: Admin status for ${user.id}: $adminStatus');

      if (mounted) {
        setState(() => isAdmin = adminStatus);
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _loadPosts() async {
    debugPrint('PostsFeed: _loadPosts called, isAdmin=$isAdmin');
    try {
      // Load posts that haven't expired
      final now = DateTime.now().toIso8601String();
      final user = supabase.auth.currentUser;

      List data;
      if (isAdmin) {
        debugPrint('PostsFeed: Loading ALL posts (admin mode)');
        // Admins see ALL posts (approved + pending + their own)
        data = await supabase
            .from('club_posts')
            .select('''
              id, title, content, author_id, author_name, created_at, is_approved, expiry_date,
              user_profiles!club_posts_author_id_fkey(full_name, avatar_url, membership_type),
              club_post_attachments(*)
            ''')
            .gte('expiry_date', now)
            .order('created_at', ascending: false);
      } else if (user != null) {
        // Non-admins see approved posts OR own posts (no join to avoid RLS issues)
        final approved = await supabase
            .from('club_posts')
            .select('''
              id, title, content, author_id, author_name, created_at, is_approved, expiry_date,
              user_profiles!club_posts_author_id_fkey(full_name, avatar_url, membership_type),
              club_post_attachments(*)
            ''')
            .gte('expiry_date', now)
            .eq('is_approved', true)
            .order('created_at', ascending: false);

        final mine = await supabase
            .from('club_posts')
            .select('''
              id, title, content, author_id, author_name, created_at, is_approved, expiry_date,
              user_profiles!club_posts_author_id_fkey(full_name, avatar_url, membership_type),
              club_post_attachments(*)
            ''')
            .gte('expiry_date', now)
            .eq('author_id', user.id)
            .order('created_at', ascending: false);

        // Merge unique by id
        final seen = <String>{};
        data = [];
        for (final row in approved) {
          if (seen.add(row['id'] as String)) data.add(row);
        }
        for (final row in mine) {
          if (seen.add(row['id'] as String)) data.add(row);
        }
        // Sort by created_at descending
        data.sort(
          (a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String),
        );
      } else {
        data = [];
      }

      if (mounted) {
        debugPrint('PostsFeed: Loaded ${data.length} posts');
        setState(() {
          posts = List<Map<String, dynamic>>.from(data);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) {
        setState(() => loading = false);
      }
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

  String _shortId(String? id) {
    if (id == null || id.isEmpty) return 'Member';
    if (id.length <= 6) return id;
    return 'Member ${id.substring(0, 6)}';
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
              _loadPosts(); // Refresh after creating post
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
                  if (index == 0) {
                    print(
                      'PostsFeed: Building posts, isAdmin=$isAdmin, count=${posts.length}',
                    );
                  }
                  final fallbackAuthorName = (post['author_name'] as String?)
                      ?.trim();
                  final authorAvatarUrl =
                      post['user_profiles']?['avatar_url'] as String?;

                  if (index == 0) {
                    print(
                      'PostsFeed: First post data: id=$postId, author_name=$fallbackAuthorName, post_keys=${post.keys.toList()}',
                    );
                  }

                  final displayAuthor =
                      (fallbackAuthorName != null &&
                          fallbackAuthorName.isNotEmpty)
                      ? fallbackAuthorName
                      : _shortId(post['author_id'] as String?);
                  final commentsCount = 0;
                  final attachments =
                      (post['club_post_attachments'] as List?)
                          ?.map((e) => e as Map<String, dynamic>)
                          .toList() ??
                      [];
                  final timeAgo = _getTimeAgo(post['created_at']);
                  final isApproved = post['is_approved'] ?? true;

                  // Build the card widget
                  final card = Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.grey[850],
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailPage(postId: post['id']),
                          ),
                        ).then((_) => _loadPosts());
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with author and time
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(1.6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _membershipColor(
                                        post['user_profiles']?['membership_type']
                                            as String?,
                                      ),
                                      width: 1.6,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.white12,
                                    backgroundImage: authorAvatarUrl != null
                                        ? NetworkImage(
                                            '$authorAvatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                                          )
                                        : null,
                                    child: authorAvatarUrl == null
                                        ? Text(
                                            displayAuthor[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayAuthor,
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
                                if (!isApproved)
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
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Title
                            Text(
                              post['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Content preview
                            Text(
                              post['content'] ?? '',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[300],
                                height: 1.4,
                              ),
                            ),

                            // Attachments inline
                            if (attachments.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // First image large
                                      if (images.isNotEmpty)
                                        ClipRRect(
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
                                      // Rest as small chips
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
                                            ...videos.map(
                                              (a) => ActionChip(
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
                                                onPressed: () async {
                                                  final url =
                                                      a['url'] as String?;
                                                  if (url == null ||
                                                      url.isEmpty) {
                                                    return;
                                                  }
                                                  try {
                                                    await launchUrl(
                                                      Uri.parse(url),
                                                      mode: LaunchMode
                                                          .externalApplication,
                                                    );
                                                  } catch (_) {}
                                                },
                                              ),
                                            ),
                                            ...files.map(
                                              (a) => ActionChip(
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
                                                onPressed: () async {
                                                  final url =
                                                      a['url'] as String?;
                                                  if (url == null ||
                                                      url.isEmpty) {
                                                    return;
                                                  }
                                                  try {
                                                    await launchUrl(
                                                      Uri.parse(url),
                                                      mode: LaunchMode
                                                          .externalApplication,
                                                    );
                                                  } catch (_) {}
                                                },
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

                            // Footer with expandable emoji and comments
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Expandable emoji button
                                Container(
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
                                        Icons.add,
                                        size: 14,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Comment count
                                Icon(
                                  Icons.comment_outlined,
                                  size: 18,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$commentsCount',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  // Wrap card in Dismissible for admin swipe-to-delete
                  if (isAdmin) {
                    print(
                      'PostsFeed: Wrapping post $postId in Dismissible (admin=$isAdmin)',
                    );
                    return Dismissible(
                      key: ValueKey('post-$postId'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      secondaryBackground: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
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
                      },
                      onDismissed: (_) async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await supabase
                              .from('club_posts')
                              .delete()
                              .eq('id', postId);
                          await _loadPosts();
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Post deleted')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error deleting post: $e'),
                              ),
                            );
                          }
                          await _loadPosts();
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
}
