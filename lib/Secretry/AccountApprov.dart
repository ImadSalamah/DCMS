import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../providers/language_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:convert';
import 'package:provider/provider.dart';

class AccountApprovalPage extends StatefulWidget {
  const AccountApprovalPage({super.key});

  @override
  _AccountApprovalPageState createState() => _AccountApprovalPageState();
}

class _AccountApprovalPageState extends State<AccountApprovalPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _pendingUsers = [];
  bool _isLoading = true;
  String? _rejectionReason;
  final _rejectionReasonController = TextEditingController();

  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);

  final Map<String, Map<String, String>> _translations = {
    'approval_title': {'ar': 'الموافقة على الحسابات', 'en': 'Account Approval'},
    'no_pending_users': {'ar': 'لا يوجد حسابات معلقة', 'en': 'No pending accounts'},
    'user_info': {'ar': 'معلومات المستخدم', 'en': 'User Information'},
    'full_name': {'ar': 'الاسم الكامل', 'en': 'Full Name'},
    'id_number': {'ar': 'رقم الهوية', 'en': 'ID Number'},
    'birth_date': {'ar': 'تاريخ الميلاد', 'en': 'Birth Date'},
    'gender': {'ar': 'الجنس', 'en': 'Gender'},
    'male': {'ar': 'ذكر', 'en': 'Male'},
    'female': {'ar': 'أنثى', 'en': 'Female'},
    'phone': {'ar': 'رقم الهاتف', 'en': 'Phone Number'},
    'address': {'ar': 'مكان السكن', 'en': 'Address'},
    'email': {'ar': 'البريد الإلكتروني', 'en': 'Email'},
    'approve': {'ar': 'موافقة', 'en': 'Approve'},
    'reject': {'ar': 'رفض', 'en': 'Reject'},
    'approval_success': {'ar': 'تمت الموافقة بنجاح', 'en': 'Approval successful'},
    'rejection_success': {'ar': 'تم الرفض بنجاح', 'en': 'Rejection successful'},
    'error': {'ar': 'حدث خطأ', 'en': 'Error occurred'},
    'profile_image': {'ar': 'الصورة الشخصية', 'en': 'Profile Image'},
    'rejection_reason': {'ar': 'سبب الرفض', 'en': 'Rejection Reason'},
    'enter_rejection_reason': {'ar': 'الرجاء إدخال سبب الرفض', 'en': 'Please enter rejection reason'},
    'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
    'submit_rejection': {'ar': 'إرسال الرفض', 'en': 'Submit Rejection'},
    'not_available': {'ar': 'غير متاح', 'en': 'N/A'},
  };

  String _translate(String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]![languageProvider.isEnglish ? 'en' : 'ar'] ?? key;
  }

  String _formatBirthDate(dynamic birthDate, bool isEnglish) {
    try {
      if (birthDate == null) return _translate('not_available');
      final timestamp = int.tryParse(birthDate.toString()) ?? 0;
      if (timestamp == 0) return _translate('not_available');
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('dd/MM/yyyy', isEnglish ? 'en' : 'ar').format(date);
    } catch (e) {
      return _translate('not_available');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPendingUsers();
  }

  Future<void> _loadPendingUsers() async {
    try {
      final snapshot = await _database.child('pendingUsers').once();
      if (snapshot.snapshot.value != null) {
        final Map<dynamic, dynamic> usersMap = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> usersList = [];

        usersMap.forEach((key, value) {
          final userData = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          userData['userId'] = key;
          usersList.add(userData);
        });

        setState(() {
          _pendingUsers = usersList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _pendingUsers = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_translate('error')}: $e')),
      );
    }
  }

  Future<void> _approveUser(Map<String, dynamic> userData) async {
    try {
      final userId = userData['userId'];
      final authUid = userData['authUid'];

      // Remove from pending users
      await _database.child('pendingUsers/$userId').remove();

      // Add to active users
      await _database.child('users/$userId').set(userData);

      // Mark notification as read
      await _markNotificationAsRead(authUid);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate('approval_success'))),
      );

      _loadPendingUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_translate('error')}: $e')),
      );
    }
  }

  Future<void> _rejectUser(Map<String, dynamic> userData, {String? reason}) async {
    try {
      final userId = userData['userId'];
      final authUid = userData['authUid'];

      // Remove from pending users
      await _database.child('pendingUsers/$userId').remove();

      // Add to rejected users with reason if provided
      if (reason != null && reason.isNotEmpty) {
        await _database.child('rejectedUsers/$userId').set({
          ...userData,
          'rejectionReason': reason,
          'rejectedAt': ServerValue.timestamp,
        });
      }

      // Mark notification as read
      await _markNotificationAsRead(authUid);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate('rejection_success'))),
      );

      _loadPendingUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_translate('error')}: $e')),
      );
    }
  }

  Future<void> _markNotificationAsRead(String authUid) async {
    try {
      final snapshot = await _database.child('notifications').once();
      if (snapshot.snapshot.value != null) {
        final Map<dynamic, dynamic> notifications = snapshot.snapshot.value as Map<dynamic, dynamic>;

        notifications.forEach((secretaryId, userNotifications) {
          final Map<dynamic, dynamic> notificationsMap = userNotifications as Map<dynamic, dynamic>;

          notificationsMap.forEach((notificationId, notificationData) {
            final notification = Map<String, dynamic>.from(notificationData as Map<dynamic, dynamic>);
            if (notification['userId'] == authUid && notification['type'] == 'new_account') {
              _database.child('notifications/$secretaryId/$notificationId/read').set(true);
            }
          });
        });
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  void _showRejectionDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_translate('rejection_reason')),
          content: TextField(
            controller: _rejectionReasonController,
            decoration: InputDecoration(
              hintText: _translate('enter_rejection_reason'),
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (value) {
              setState(() {
                _rejectionReason = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectionReasonController.clear();
              },
              child: Text(_translate('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                if (_rejectionReason != null && _rejectionReason!.isNotEmpty) {
                  Navigator.pop(context);
                  _rejectUser(user, reason: _rejectionReason);
                  _rejectionReasonController.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_translate('enter_rejection_reason'))),
                  );
                }
              },
              child: Text(_translate('submit_rejection')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserImage(String? imageData) {
    if (imageData == null || imageData.isEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.person,
          size: 40,
          color: Colors.grey[600],
        ),
      );
    }

    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.memory(
          base64Decode(imageData.replaceFirst('data:image/jpeg;base64,', '')),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.error_outline,
              size: 40,
              color: Colors.red,
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _translate('user_info'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),

            // Profile Image Section
            Center(
              child: Column(
                children: [
                  Text(
                    _translate('profile_image'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildUserImage(user['image']),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildUserInfoRow(
              label: _translate('full_name'),
              value: '${user['firstName']} ${user['fatherName']} ${user['grandfatherName']} ${user['familyName']}',
            ),
            _buildUserInfoRow(
              label: _translate('id_number'),
              value: user['idNumber'] ?? _translate('not_available'),
            ),
            _buildUserInfoRow(
              label: _translate('birth_date'),
              value: _formatBirthDate(user['birthDate'], languageProvider.isEnglish),
            ),
            _buildUserInfoRow(
              label: _translate('gender'),
              value: user['gender'] == 'male' ? _translate('male') : _translate('female'),
            ),
            _buildUserInfoRow(
              label: _translate('phone'),
              value: user['phone'] ?? _translate('not_available'),
            ),
            _buildUserInfoRow(
              label: _translate('address'),
              value: user['address'] ?? _translate('not_available'),
            ),
            _buildUserInfoRow(
              label: _translate('email'),
              value: user['email'] ?? _translate('not_available'),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _showRejectionDialog(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(_translate('reject')),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _approveUser(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(_translate('approve')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(_translate('approval_title')),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pendingUsers.isEmpty
            ? Center(
          child: Text(
            _translate('no_pending_users'),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _pendingUsers.length,
          itemBuilder: (context, index) {
            return _buildUserCard(_pendingUsers[index]);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }
}