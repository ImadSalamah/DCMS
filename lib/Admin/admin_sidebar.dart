import 'package:flutter/material.dart';
import 'dart:convert';
import '../dashboard/admin_dashboard.dart';

class AdminSidebar extends StatelessWidget {
  final Color primaryColor;
  final Color accentColor;
  final String? userName;
  final String? userImageUrl;
  final VoidCallback? onLogout;
  final BuildContext parentContext;

  const AdminSidebar({
    super.key,
    required this.primaryColor,
    required this.accentColor,
    this.userName,
    this.userImageUrl,
    this.onLogout,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                userImageUrl != null && userImageUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: Image.memory(
                            // Properly decode base64 string to Uint8List
                            base64Decode(userImageUrl!.replaceFirst('data:image/jpeg;base64,', '')),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 32, color: accentColor),
                      ),
                const SizedBox(height: 10),
                Text(
                  userName ?? 'Admin',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                const Text(
                  'System Admin',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: primaryColor),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                parentContext,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
                (route) => false,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.people, color: primaryColor),
            title: const Text('Manage Users'),
            onTap: () {
              // Implement navigation to manage users
            },
          ),
          ListTile(
            leading: Icon(Icons.person_add, color: primaryColor),
            title: const Text('Add User'),
            onTap: () {
              // Implement navigation to add user
            },
          ),
          ListTile(
            leading: Icon(Icons.group, color: primaryColor),
            title: const Text('Manage Study Groups'),
            onTap: () {
              // Implement navigation to manage study groups
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: primaryColor),
            title: const Text('Settings'),
            onTap: () {
              // Implement navigation to settings
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
