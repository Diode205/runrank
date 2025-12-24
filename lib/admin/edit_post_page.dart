import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditPostPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late DateTime _expiryDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.post['title'] as String? ?? '',
    );
    _contentController = TextEditingController(
      text: widget.post['content'] as String? ?? '',
    );
    try {
      final expiryStr = widget.post['expiry_date'] as String?;
      if (expiryStr != null && expiryStr.isNotEmpty) {
        _expiryDate = DateTime.parse(expiryStr);
      } else {
        _expiryDate = DateTime.now().add(const Duration(days: 365));
      }
    } catch (e) {
      debugPrint('Error parsing expiry_date: $e');
      _expiryDate = DateTime.now().add(const Duration(days: 365));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate()) return;

    final postId = widget.post['id'] as String?;
    if (postId == null || postId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error: Invalid post ID')));
      }
      return;
    }

    setState(() => _saving = true);

    try {
      await supabase
          .from('club_posts')
          .update({
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'expiry_date': _expiryDate.toIso8601String(),
          })
          .eq('id', postId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully')),
        );
        Navigator.pop(context, true); // Signal that post was updated
      }
    } catch (e) {
      debugPrint('Error updating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      debugPrint('Error updating post: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        elevation: 0,
        backgroundColor: Colors.grey[900],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Content field
                TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    labelText: 'Content',
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  minLines: 5,
                  maxLines: 10,
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Content is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Expiry date picker
                ListTile(
                  title: const Text('Expiry Date'),
                  subtitle: Text(_expiryDate.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1095)),
                    );
                    if (picked != null) {
                      setState(() => _expiryDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0057B7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _saving ? null : _savePost,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
