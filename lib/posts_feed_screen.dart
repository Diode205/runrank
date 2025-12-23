import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Track expanded states
  final Map<String, bool> _expandedReactions = {};
  final Map<String, bool> _expandedComments = {};
  final Map<String, TextEditingController> _commentControllers = {};

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

  Future<void> _loadPosts() async {
    try {
      // Load posts that haven't expired
      final now = DateTime.now().toIso8601String();
      final user = supabase.auth.currentUser;

      List data;
      if (isAdmin) {
        // Admins see ALL posts
        data = await supabase
            .from('club_posts')
            .select('''
              *,
              user_profiles!club_posts_author_id_fkey(full_name),
              club_post_attachments(*)
            ''')
            .gte('expiry_date', now)
            .order('created_at', ascending: false);
      } else if (user != null) {
        // Non-admins see approved posts OR own posts
        final approved = await supabase
            .from('club_posts')
            .select('''
              *,
              user_profiles!club_posts_author_id_fkey(full_name),
              club_post_attachments(*)
            ''')
            .gte('expiry_date', now)
            .eq('is_approved', true)
            .order('created_at', ascending: false);

        final mine = await supabase
            .from('club_posts')
            .select('''
              *,
              user_profiles!club_posts_author_id_fkey(full_name),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post approved')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectPost(String postId) async {
    try {
      await supabase.from('club_posts').delete().eq('id', postId);
      await _loadPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post rejected and deleted')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                  final authorName =
                      post['user_profiles']?['full_name'] ?? 'Unknown';
                  final commentsCount = 0;
                  final attachments =
                      (post['club_post_attachments'] as List?)
                          ?.map((e) => e as Map<String, dynamic>)
                          .toList() ??
                      [];
                  final timeAgo = _getTimeAgo(post['created_at']);
                  final isApproved = post['is_approved'] ?? true;
                  final postId = post['id'] as String;

                  // Build the card widget
                  final card = Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.grey[850],
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                    return Dismissible(
                      key: Key(postId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      onDismissed: (_) async {
                        try {
                          await supabase.from('club_posts').delete().eq('id', postId);
                          await _loadPosts();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post deleted')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting post: $e')),
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
