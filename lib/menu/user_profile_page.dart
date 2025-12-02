import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/menu/membership_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic>? _profile;

  // Controllers
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _uka = TextEditingController();
  String? _avatarUrl;
  DateTime? _memberSince;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = await _client
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      _profile = data;
      _fullName.text = data?['full_name'] ?? '';
      _uka.text = data?['uka_number'] ?? '';
      _avatarUrl = data?['avatar_url'];
      _memberSince = DateTime.tryParse(data?['created_at'] ?? '');
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('user_profiles')
        .update({
          "full_name": _fullName.text.trim(),
          "uka_number": _uka.text.trim(),
          "avatar_url": _avatarUrl,
        })
        .eq("id", user.id);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Profile updated")));
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);

    if (img == null) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    final file = File(img.path);

    final fileExt = img.path.split('.').last;
    final fileName = "avatar_${user.id}.$fileExt";

    await _client.storage
        .from("avatars")
        .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

    final publicUrl = _client.storage.from("avatars").getPublicUrl(fileName);

    setState(() => _avatarUrl = publicUrl);

    await _saveProfile();
  }

  String _formatMemberSince(DateTime? d) {
    if (d == null) return "Unknown";

    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${months[d.month - 1]} ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final email = _client.auth.currentUser?.email ?? "";

    return Scaffold(
      appBar: AppBar(title: const Text("Your Profile")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ------------------------------
          // Avatar
          // ------------------------------
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _avatarUrl != null
                      ? NetworkImage(_avatarUrl!)
                      : null,
                  child: _avatarUrl == null
                      ? const Icon(Icons.person, size: 60)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ------------------------------
          // Member since
          // ------------------------------
          Center(
            child: Text(
              "Member since ${_formatMemberSince(_memberSince)}",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),

          const SizedBox(height: 20),

          // ------------------------------
          // Email (read only)
          // ------------------------------
          TextFormField(
            initialValue: email,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // ------------------------------
          // Full Name
          // ------------------------------
          TextField(
            controller: _fullName,
            decoration: const InputDecoration(
              labelText: "Full Name",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // ------------------------------
          // UKA Number
          // ------------------------------
          TextField(
            controller: _uka,
            decoration: const InputDecoration(
              labelText: "UKA Number",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 30),

          // ------------------------------
          // Save Btn
          // ------------------------------
          ElevatedButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save),
            label: const Text("Save Changes"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          const SizedBox(height: 20),

          // ------------------------------
          // Membership / Renewal Shortcut
          // ------------------------------
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MembershipPage()),
              );
            },
            icon: const Icon(Icons.card_membership),
            label: const Text("Membership & Renewal"),
          ),
        ],
      ),
    );
  }
}
