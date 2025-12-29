import 'package:flutter/material.dart';
import 'package:runrank/services/user_service.dart';

class AdministrativeTeamPage extends StatefulWidget {
  const AdministrativeTeamPage({super.key});

  @override
  State<AdministrativeTeamPage> createState() => _AdministrativeTeamPageState();
}

class _AdministrativeTeamPageState extends State<AdministrativeTeamPage> {
  bool _isAdmin = false;

  final List<Map<String, String>> _committee = [
    {'role': 'President', 'name': 'Noel Spruce', 'email': ''},
    {
      'role': 'Chairperson',
      'name': 'Ness Dent',
      'email': 'chairperson@nnbr.co.uk',
    },
    {'role': 'Vice-Chairperson', 'name': 'Richard West', 'email': ''},
    {'role': 'Secretary', 'name': 'Gav Dent', 'email': 'secretary@nnbr.co.uk'},
    {
      'role': 'Treasurer',
      'name': 'Peter Hill',
      'email': 'treasurer@nnbr.co.uk',
    },
    {'role': 'Membership Secretary', 'name': 'Libby Ashton', 'email': ''},
    {
      'role': 'Minutes Secretary',
      'name': 'Rachel Welch',
      'email': 'minutes_secretary@nnbr.co.uk',
    },
    {'role': 'Clothing Manager', 'name': 'Sarah Morter', 'email': ''},
    {'role': 'Club Head Coach', 'name': 'Karen Balcombe', 'email': ''},
    {'role': 'Equipment Store Manager', 'name': 'Phil King', 'email': ''},
    {'role': 'General Committee Member', 'name': 'Neil Adams', 'email': ''},
    {'role': 'General Committee Member', 'name': 'Tony Witmond', 'email': ''},
    {'role': 'Webmaster', 'name': 'John Fagan', 'email': ''},
    {'role': 'Press Officer', 'name': 'John Worrall', 'email': ''},
  ];

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    _isAdmin = await UserService.isAdmin();
    if (mounted) setState(() {});
  }

  void _editMember(int index) {
    if (!_isAdmin) return;

    final member = _committee[index];
    final nameController = TextEditingController(text: member['name']);
    final emailController = TextEditingController(text: member['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Edit ${member['role']}',
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _committee[index]['name'] = nameController.text.trim();
                _committee[index]['email'] = emailController.text.trim();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showContactForm(int index) {
    final member = _committee[index];
    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Contact ${member['name']}',
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Role: ${member['role']}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Subject',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF0055FF),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF0055FF),
                      width: 2,
                    ),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (subjectController.text.trim().isEmpty ||
                  messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // TODO: Store enquiry in Supabase or send via email service
              // For now, show a confirmation
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Message sent to ${member['name']}. Thank you!',
                  ),
                  backgroundColor: const Color(0xFF0055FF),
                ),
              );
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Club Committee',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1A3A), Color(0xFF0D2F5A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF1E406A), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Color(0xFFFFD700), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'The NNBR Team Committee',
                          style: TextStyle(
                            color: Color.fromARGB(255, 238, 228, 30),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'For general enquiries, please contact The Chairperson or The Secretary via email.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _committee.length,
              itemBuilder: (context, index) {
                final member = _committee[index];
                final hasEmail = (member['email'] ?? '').isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: const Color(0xFF0055FF).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0055FF),
                                    Color(0xFF0088FF),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['role'] ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFF56D3FF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    member['name'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (hasEmail)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        member['email'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 40), // Space for buttons
                          ],
                        ),
                      ),
                      // Edit button (top right corner)
                      if (_isAdmin)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _editMember(index),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFD700,
                                  ).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withOpacity(0.4),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Color(0xFFFFD700),
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Mail button (bottom right corner)
                      if (hasEmail)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showContactForm(index),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF56D3FF,
                                  ).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF56D3FF,
                                    ).withOpacity(0.4),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.send,
                                  color: Color(0xFF56D3FF),
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
