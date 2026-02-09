import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:runrank/services/user_service.dart';
import 'dart:io';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  // Admin status
  bool _isAdmin = false;
  // Title category dropdown
  String _titleCategory = 'Announcement';
  bool _useCustomTitle = false;
  // Attachments collected via + button (images or URLs)
  final List<Map<String, String>> _attachments = [];
  bool _uploading = false;
  bool _attachmentUploading = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    // Initialize title from default category
    _titleController.text = _titleCategory;
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
        setState(() => _isAdmin = (profile?['is_admin'] ?? false) as bool);
      }
    } catch (_) {}
  }

  Future<File?> _pickImageFrom(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return null;
    return File(pickedFile.path);
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'club_posts/$fileName';

      await supabase.storage.from('club-media').upload(path, image);

      final publicUrl = supabase.storage.from('club-media').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _addAttachmentFromGallery() async {
    final file = await _pickImageFrom(ImageSource.gallery);
    if (file == null) return;
    final url = await _uploadImage(file);
    if (url != null) {
      setState(() {
        _attachments.add({'type': 'image', 'url': url, 'name': 'Image'});
      });
    }
  }

  Future<void> _addAttachmentFromCamera() async {
    final file = await _pickImageFrom(ImageSource.camera);
    if (file == null) return;
    final url = await _uploadImage(file);
    if (url != null) {
      setState(() {
        _attachments.add({'type': 'image', 'url': url, 'name': 'Image'});
      });
    }
  }

  Future<void> _addAttachmentVideo() async {
    try {
      if (mounted) {
        setState(() {
          _attachmentUploading = true;
        });
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile == null) {
        if (mounted) {
          setState(() {
            _attachmentUploading = false;
          });
        }
        return;
      }

      final file = File(pickedFile.path);
      final fileName = pickedFile.name;

      const maxVideoBytes = 50 * 1024 * 1024; // ~50MB
      final fileSize = await file.length();
      if (fileSize > maxVideoBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Video too large. Please upload a shorter or compressed clip (max ~50MB).',
              ),
            ),
          );
          setState(() {
            _attachmentUploading = false;
          });
        }
        return;
      }

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final storagePath =
          'club_posts/${user.id}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await supabase.storage.from('club-media').upload(storagePath, file);

      final publicUrl = supabase.storage
          .from('club-media')
          .getPublicUrl(storagePath);
      setState(() {
        _attachments.add({'type': 'video', 'url': publicUrl, 'name': fileName});
        _attachmentUploading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading video: $e')));
        setState(() {
          _attachmentUploading = false;
        });
      }
    }
  }

  Future<void> _addAttachmentFile() async {
    try {
      if (mounted) {
        setState(() {
          _attachmentUploading = true;
        });
      }

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'mp4',
          'mov',
          'avi',
          'mkv',
          'webm',
          'flv',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'zip',
        ],
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) {
          setState(() {
            _attachmentUploading = false;
          });
        }
        return;
      }
      final picked = result.files.single;
      final file = File(picked.path!);
      final fileName = picked.name;

      // Enforce a soft size limit for video files to avoid large storage usage
      final lowerName = fileName.toLowerCase();
      final isVideo =
          lowerName.endsWith('.mp4') ||
          lowerName.endsWith('.mov') ||
          lowerName.endsWith('.avi') ||
          lowerName.endsWith('.mkv') ||
          lowerName.endsWith('.webm') ||
          lowerName.endsWith('.flv');

      const maxVideoBytes = 50 * 1024 * 1024; // ~50MB
      if (isVideo && picked.size > maxVideoBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Video too large. Please upload a shorter or compressed clip (max ~50MB).',
              ),
            ),
          );
          setState(() {
            _attachmentUploading = false;
          });
        }
        return;
      }

      // Upload file to storage
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final storagePath =
          'club_posts/${user.id}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await supabase.storage.from('club-media').upload(storagePath, file);

      final publicUrl = supabase.storage
          .from('club-media')
          .getPublicUrl(storagePath);

      // Determine attachment type based on file extension
      String attachmentType = 'file';
      if (lowerName.endsWith('.png') ||
          lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.gif') ||
          lowerName.endsWith('.webp')) {
        attachmentType = 'image';
      } else if (isVideo) {
        attachmentType = 'video';
      }

      setState(() {
        _attachments.add({
          'type': attachmentType,
          'url': publicUrl,
          'name': fileName,
        });
        _attachmentUploading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
        setState(() {
          _attachmentUploading = false;
        });
      }
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _uploading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      if (await UserService.isBlocked(context: context)) {
        setState(() => _uploading = false);
        return;
      }
      // Fetch author display name for denormalized storage (avoids RLS on user_profiles)
      String authorName = 'Unknown';
      try {
        final profile = await supabase
            .from('user_profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        final name = profile?['full_name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          authorName = name.trim();
        } else {
          // Fallback to user metadata if available
          final displayName = user.userMetadata?['full_name'] as String?;
          if (displayName != null && displayName.trim().isNotEmpty) {
            authorName = displayName.trim();
          }
        }
      } catch (e) {
        debugPrint('Error fetching author name: $e');
        // Fallback to user metadata
        final displayName = user.userMetadata?['full_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          authorName = displayName.trim();
        }
      }

      // Determine approval
      final isApproved = _isAdmin;

      // Compose title depending on category/custom
      final titleText = _useCustomTitle
          ? _titleController.text.trim()
          : _titleCategory;

      // Insert post and return id
      final inserted = await supabase
          .from('club_posts')
          .insert({
            'title': titleText,
            'content': _contentController.text.trim(),
            'author_id': user.id,
            'author_name': authorName,
            'expiry_date': _expiryDate.toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'is_approved': isApproved,
          })
          .select('id')
          .single();

      final postId = inserted['id'] as String;

      // Save attachments
      for (final att in _attachments) {
        await supabase.from('club_post_attachments').insert({
          'post_id': postId,
          'type': att['type'],
          'url': att['url'],
          'name': att['name'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApproved
                  ? 'Post published successfully!'
                  : 'Post submitted — awaiting approval from an admin.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating post: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
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
      body: _uploading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Approval policy notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Center(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text:
                                    'All posts are subject to Admin approval. Any post that is deemed irrelevant and or unnecessary may not be published. Please refer to Club Policies on Privacy, Health & Safety, and Data Protection. ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                              TextSpan(
                                text: 'Contact',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFFFD300),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  height: 1.5,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst);
                                    // Navigate to admin in menu
                                    Navigator.of(context).pushNamed('/menu');
                                  },
                              ),
                              const TextSpan(
                                text:
                                    ' your Admin for clarification and guidance.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title category + optional custom title (responsive)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _titleCategory,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[850],
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Announcement',
                              child: Text('Announcement'),
                            ),
                            DropdownMenuItem(
                              value: 'Race Report',
                              child: Text('Race Report'),
                            ),
                            DropdownMenuItem(
                              value: 'Standard/Age Grade Report',
                              child: Text('Standard/Age Grade Report'),
                            ),
                            DropdownMenuItem(
                              value: 'Team Briefing',
                              child: Text('Team Briefing'),
                            ),
                            DropdownMenuItem(
                              value: 'Custom',
                              child: Text('Other...'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _titleCategory = v;
                              _useCustomTitle = v == 'Custom';
                              if (!_useCustomTitle) {
                                _titleController.text = v;
                              } else {
                                // Clear the field for custom title
                                _titleController.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        // Custom title field (always present but hidden if not needed)
                        if (_useCustomTitle)
                          TextFormField(
                            autofocus: true,
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Custom Title',
                              hintText: 'Enter your custom title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[850],
                            ),
                            style: const TextStyle(fontSize: 16),
                            validator: (value) {
                              if (_useCustomTitle &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Enter a title';
                              }
                              return null;
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Content field
                    Stack(
                      children: [
                        TextFormField(
                          controller: _contentController,
                          decoration: InputDecoration(
                            labelText: 'Content',
                            hintText:
                                'Share your news, race report, or running story...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[850],
                            alignLabelWithHint: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                          maxLines: 10,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter content';
                            }
                            return null;
                          },
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Photo from Gallery',
                                onPressed: _attachmentUploading
                                    ? null
                                    : _addAttachmentFromGallery,
                                icon: const Icon(
                                  Icons.image,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Take Photo',
                                onPressed: _attachmentUploading
                                    ? null
                                    : _addAttachmentFromCamera,
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Attach Document',
                                onPressed: _attachmentUploading
                                    ? null
                                    : _addAttachmentFile,
                                icon: const Icon(
                                  Icons.attach_file,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Attach Video',
                                onPressed: _attachmentUploading
                                    ? null
                                    : _addAttachmentVideo,
                                icon: const Icon(
                                  Icons.videocam,
                                  color: Colors.purple,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tip: Any https:// link in Content becomes a tappable link in the post. '
                      'Videos are limited to about 50MB to save storage.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (_attachmentUploading) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Uploading attachment... please wait before publishing.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachments
                            .map(
                              (att) => Chip(
                                label: Text(
                                  att['name'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                avatar: Icon(
                                  att['type'] == 'image'
                                      ? Icons.image
                                      : att['type'] == 'file'
                                      ? Icons.description
                                      : Icons.link,
                                  size: 18,
                                ),
                                onDeleted: () {
                                  setState(() => _attachments.remove(att));
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Unless removed by Admin, post expires one year from date of publication.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0057B7), Color(0xFF003F8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x4D0057B7),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: (_uploading || _attachmentUploading)
                            ? null
                            : _submitPost,
                        icon: const Icon(Icons.send),
                        label: const Text('Publish Post'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
