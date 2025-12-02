import 'package:flutter/material.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:runrank/menu/membership_page.dart';
import 'package:runrank/menu/user_profile_page.dart';
import 'package:runrank/menu/charity_page.dart';
import 'package:runrank/menu/club_history_page.dart';
import 'package:runrank/menu/merchandise_page.dart';
import 'package:runrank/admin/admin_charity_page.dart';
import 'package:runrank/auth/login_screen.dart';
import 'package:runrank/services/user_service.dart'; // NEW – to check if admin

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final isAdmin = await UserService.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Menu"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ------------------------------
          // PROFILE SECTION
          // ------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Account",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),

          _menuTile(
            icon: Icons.person,
            title: "User Profile",
            subtitle: "Edit details • UKA number • Member since",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfilePage()),
              );
            },
          ),

          _menuTile(
            icon: Icons.card_membership,
            title: "Membership",
            subtitle: "Membership details and renewal",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MembershipPage()),
              );
            },
          ),

          // ------------------------------
          // CLUB SECTION
          // ------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "Club",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),

          _menuTile(
            icon: Icons.favorite,
            title: "Charity of the Year",
            subtitle: "Club charity, donation link & total raised",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CharityPage()),
              );
            },
          ),

          if (_isAdmin)
            _menuTile(
              icon: Icons.edit,
              title: "Edit Charity Details",
              subtitle: "Admin only — update charity & totals",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminCharityEditorPage(),
                  ),
                );
              },
            ),

          _menuTile(
            icon: Icons.shopping_bag,
            title: "Club Merchandise",
            subtitle: "Order club kit & apparel",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MerchandisePage()),
              );
            },
          ),

          _menuTile(
            icon: Icons.history_edu,
            title: "Club History",
            subtitle: "Learn about NNBR’s story",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClubHistoryPage()),
              );
            },
          ),

          const SizedBox(height: 20),

          // ------------------------------
          // LOG OUT
          // ------------------------------
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                await AuthService.logout();

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                "Log Out",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // COPYRIGHT
          const Center(
            child: Text(
              "© 2025 RunRank · All rights reserved",
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 30, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
