import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../providers/language_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../dashboard/secretary_dashboard.dart';
import '../Student/patient_files.dart';
import '../Shared/waiting_list_page.dart';
import '../loginpage.dart';

class AccountApprovalPage extends StatefulWidget {
  const AccountApprovalPage({super.key});

  @override
  AccountApprovalPageState createState() => AccountApprovalPageState();
}

class AccountApprovalPageState extends State<AccountApprovalPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _pendingUsers = [];
  bool _isLoading = true;

  final _rejectionReasonController = TextEditingController();

  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);

  // Rejection UI state
  Map<String, dynamic>? _rejectingUser;
  List<String> _selectedFields = [];
  bool _rejectAll = true;

  final Map<String, Map<String, String>> _translations = const {
    'approval_title': {'ar': 'الموافقة على الحسابات', 'en': 'Account Approval'},
    'no_pending_users': {
      'ar': 'لا يوجد حسابات معلقة',
      'en': 'No pending accounts'
    },
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
    'approval_success': {
      'ar': 'تمت الموافقة بنجاح',
      'en': 'Approval successful'
    },
    'rejection_success': {'ar': 'تم الرفض بنجاح', 'en': 'Rejection successful'},
    'error': {'ar': 'حدث خطأ', 'en': 'Error occurred'},
    'profile_image': {'ar': 'الصورة الشخصية', 'en': 'Profile Image'},
    'rejection_reason': {'ar': 'سبب الرفض', 'en': 'Rejection Reason'},
    'enter_rejection_reason': {
      'ar': 'الرجاء إدخال سبب الرفض',
      'en': 'Please enter rejection reason'
    },
    'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
    'submit_rejection': {'ar': 'إرسال الرفض', 'en': 'Submit Rejection'},
    'not_available': {'ar': 'غير متاح', 'en': 'N/A'},
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'reject_all': {'ar': 'رفض كامل', 'en': 'Reject All'},
    'select_fields': {
      'ar': 'تحديد بيانات للتعديل',
      'en': 'Select Fields to Edit'
    },
  };

  @override
  void initState() {
    super.initState();
    _loadPendingUsers();
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  String _translate(String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]?[languageProvider.isEnglish ? 'en' : 'ar'] ?? key;
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

  Future<void> _loadPendingUsers() async {
    try {
      setState(() => _isLoading = true);
      // read from pendingUsers instead of pendingAccounts
      final snapshot = await _database.child('pendingUsers').once();

      if (snapshot.snapshot.value == null) {
        if (mounted) {
          setState(() {
            _pendingUsers = [];
            _isLoading = false;
          });
        }
        return;
      }

      final usersMap = snapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final usersList = <Map<String, dynamic>>[];

      usersMap.forEach((key, value) {
        try {
          final userData =
              Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          userData['userId'] = key.toString();
          usersList.add(userData);
        } catch (e) {
          debugPrint('Error parsing user data: $e');
        }
      });

      if (mounted) {
        setState(() {
          _pendingUsers = usersList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_translate('error')}: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _approveUser(Map<String, dynamic> userData) async {
    try {
      final userId = userData['userId']?.toString() ?? '';
      final authUid = userData['authUid']?.toString() ?? '';

      if (userId.isEmpty || authUid.isEmpty) {
        throw Exception('Missing userId or authUid');
      }

      // Remove from pendingUsers instead of pendingAccounts
      await _database.child('pendingUsers/$userId').remove();

      final approvedUserData = Map<String, dynamic>.from(userData);
      approvedUserData['isActive'] = true;
      await _database.child('users/$userId').set(approvedUserData);

      await _markNotificationAsRead(authUid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_translate('approval_success'))),
        );
        _loadPendingUsers();
      }
    } catch (e) {
      debugPrint('Error approving user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_translate('error')}: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _rejectUser(Map<String, dynamic> userData,
      {String? reason}) async {
    try {
      final userId = userData['userId']?.toString() ?? '';
      final authUid = userData['authUid']?.toString() ?? '';

      if (userId.isEmpty || authUid.isEmpty) {
        throw Exception('Missing userId or authUid');
      }

      await _database.child('pendingAccounts/$userId').remove();

      if (reason != null && reason.isNotEmpty) {
        await _database.child('rejectedUsers/$userId').set({
          ...userData,
          'rejectionReason': reason,
          'rejectedAt': ServerValue.timestamp,
        });
      }

      await _markNotificationAsRead(authUid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_translate('rejection_success'))),
        );
        _loadPendingUsers();
      }
    } catch (e) {
      debugPrint('Error rejecting user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_translate('error')}: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _rejectUserWithFields(Map<String, dynamic> userData,
      {required String reason, required List<String> fields}) async {
    try {
      final userId = userData['userId']?.toString() ?? '';
      final authUid = userData['authUid']?.toString() ?? '';

      if (userId.isEmpty || authUid.isEmpty) {
        throw Exception('Missing userId or authUid');
      }

      await _database.child('pendingAccounts/$userId').remove();

      await _database.child('pendingAccounts/$userId').set({
        ...userData,
        'rejectionReason': reason,
        'fieldsToEdit': fields,
        'rejectedAt': ServerValue.timestamp,
      });

      await _markNotificationAsRead(authUid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_translate('rejection_success'))),
        );
        _loadPendingUsers();
      }
    } catch (e) {
      debugPrint('Error rejecting user with fields: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_translate('error')}: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _markNotificationAsRead(String authUid) async {
    try {
      final snapshot = await _database.child('notifications').once();
      if (snapshot.snapshot.value == null) return;

      final notifications =
          snapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};

      notifications.forEach((secretaryId, userNotifications) {
        try {
          final notificationsMap =
              userNotifications as Map<dynamic, dynamic>? ?? {};

          notificationsMap.forEach((notificationId, notificationData) {
            try {
              final notification = Map<String, dynamic>.from(
                  notificationData as Map<dynamic, dynamic>);
              if (notification['userId'] == authUid &&
                  notification['type'] == 'new_account') {
                _database
                    .child('notifications/$secretaryId/$notificationId/read')
                    .set(true);
              }
            } catch (e) {
              debugPrint('Error processing notification: $e');
            }
          });
        } catch (e) {
          debugPrint('Error processing secretary notifications: $e');
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  void _startRejectUser(Map<String, dynamic> user) {
    setState(() {
      _rejectingUser = user;
      _selectedFields = [];
      _rejectAll = true;
      _rejectionReasonController.clear();
    });
  }

  void _cancelRejectUser() {
    setState(() {
      _rejectingUser = null;
      _selectedFields = [];
      _rejectAll = true;
      _rejectionReasonController.clear();
    });
  }

  Widget _buildUserImage(String? imageData) {
    try {
      if (imageData == null || imageData.isEmpty) {
        return CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey[200],
          child: const Icon(
            Icons.person,
            size: 40,
            color: Colors.grey,
          ),
        );
      }

      final safeImageData = userImageSafe(imageData);
      if (safeImageData.isEmpty) throw Exception('Empty image data');

      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        child: ClipOval(
          child: Image.memory(
            base64Decode(safeImageData),
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
    } catch (e) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        child: const Icon(
          Icons.error_outline,
          size: 40,
          color: Colors.red,
        ),
      );
    }
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isRejecting =
        _rejectingUser != null && _rejectingUser?['userId'] == user['userId'];

    final List<String> editableFields = [
      'firstName',
      'fatherName',
      'grandfatherName',
      'familyName',
      'idNumber',
      'birthDate',
      'gender',
      'phone',
      'address',
      'email',
    ];

    final Map<String, String> fieldLabels = {
      'firstName': languageProvider.isEnglish ? 'First Name' : 'الاسم الأول',
      'fatherName': languageProvider.isEnglish ? 'Father Name' : 'اسم الأب',
      'grandfatherName':
          languageProvider.isEnglish ? 'Grandfather Name' : 'اسم الجد',
      'familyName': languageProvider.isEnglish ? 'Family Name' : 'اسم العائلة',
      'idNumber': _translate('id_number'),
      'birthDate': _translate('birth_date'),
      'gender': _translate('gender'),
      'phone': _translate('phone'),
      'address': _translate('address'),
      'email': _translate('email'),
      'image': _translate('profile_image'),
    };

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
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildUserImage(user['image']),
                      if (isRejecting && !_rejectAll)
                        Positioned(
                          bottom: 0,
                          right: languageProvider.isEnglish ? 0 : null,
                          left: languageProvider.isEnglish ? null : 0,
                          child: Checkbox(
                            value: _selectedFields.contains('image'),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedFields.add('image');
                                } else {
                                  _selectedFields.remove('image');
                                }
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...editableFields.map((field) {
              String value;
              if (field == 'birthDate') {
                value = _formatBirthDate(
                    user['birthDate'], languageProvider.isEnglish);
              } else if (field == 'gender') {
                final genderValue = user['gender']?.toString() ?? '';
                if (genderValue.isEmpty) {
                  value = _translate('not_available');
                } else if (genderValue == 'male') {
                  value = _translate('male');
                } else if (genderValue == 'female') {
                  value = _translate('female');
                } else {
                  value = genderValue;
                }
              } else {
                value = user[field]?.toString() ?? _translate('not_available');
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isRejecting && !_rejectAll)
                    Checkbox(
                      value: _selectedFields.contains(field),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedFields.add(field);
                          } else {
                            _selectedFields.remove(field);
                          }
                        });
                      },
                    ),
                  Expanded(
                    child: _buildUserInfoRow(
                      label: fieldLabels[field] ?? field,
                      value: value,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            if (isRejecting) ...[
              Row(
                children: [
                  Checkbox(
                    value: _rejectAll,
                    onChanged: (val) {
                      setState(() {
                        _rejectAll = val ?? true;
                        if (_rejectAll) _selectedFields.clear();
                      });
                    },
                  ),
                  Text(_translate('reject_all')),
                  Checkbox(
                    value: !_rejectAll,
                    onChanged: (val) {
                      setState(() {
                        _rejectAll = !(val ?? false);
                      });
                    },
                  ),
                  Text(_translate('select_fields')),
                ],
              ),
              TextField(
                controller: _rejectionReasonController,
                decoration: InputDecoration(
                  hintText: _translate('enter_rejection_reason'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  setState(() {
                    // _rejectionReason = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancelRejectUser,
                    child: Text(_translate('cancel')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      final reason = _rejectionReasonController.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text(_translate('enter_rejection_reason'))),
                        );
                        return;
                      }

                      if (_rejectAll || _selectedFields.isEmpty) {
                        _rejectUser(user, reason: reason);
                      } else {
                        _rejectUserWithFields(user,
                            reason: reason, fields: _selectedFields);
                      }
                      _cancelRejectUser();
                    },
                    child: Text(_translate('submit_rejection')),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _startRejectUser(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: Text(_translate('reject')),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _approveUser(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: Text(_translate('approve')),
                  ),
                ],
              ),
            ],
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
    final isLargeScreen = MediaQuery.of(context).size.width >= 800;

    return Directionality(
      textDirection:
          languageProvider.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(_translate('approval_title')),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        drawer: isLargeScreen ? null : _buildDrawer(context),
        body: isLargeScreen
            ? Row(
                children: [
                  _buildDrawer(context, permanent: true),
                  Expanded(child: _buildMainContent()),
                ],
              )
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, {bool permanent = false}) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final List<DrawerItem> drawerItems = [
      DrawerItem(
        icon: Icons.verified_user,
        label: _translate('approval_title'),
        onTap: () {
          if (!permanent) Navigator.pop(context);
        },
      ),
      DrawerItem(
        icon: Icons.folder,
        label: languageProvider.isEnglish ? 'Patient Files' : 'ملفات المرضى',
        onTap: () {
          if (permanent) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const PatientFilesPage()),
            );
          } else {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PatientFilesPage()),
            );
          }
        },
      ),
      DrawerItem(
        icon: Icons.list_alt,
        label: languageProvider.isEnglish ? 'Waiting List' : 'قائمة الانتظار',
        onTap: () {
          if (permanent) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const WaitingListPage(userRole: 'secretary')),
            );
          } else {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const WaitingListPage(userRole: 'secretary')),
            );
          }
        },
      ),
      DrawerItem(
        icon: Icons.home,
        label: _translate('home'),
        onTap: () {
          if (permanent) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SecretaryDashboard()),
            );
          } else {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SecretaryDashboard()),
            );
          }
        },
      ),
      DrawerItem(
        icon: Icons.logout,
        label: languageProvider.isEnglish ? 'Logout' : 'تسجيل خروج',
        onTap: () {
          if (permanent) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          } else {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          }
        },
      ),
    ];

    final drawerContent = ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: primaryColor),
          child: Center(
            child: Text(
              _translate('approval_title'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        ...drawerItems.map((item) => ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              onTap: item.onTap,
            )),
      ],
    );

    if (permanent) {
      return Container(
        width: 250,
        color: Colors.white,
        child: drawerContent,
      );
    }
    return Drawer(child: drawerContent);
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pendingUsers.isEmpty) {
      return Center(
        child: Text(
          _translate('no_pending_users'),
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (context, index) {
        return _buildUserCard(_pendingUsers[index]);
      },
    );
  }

  String userImageSafe(String? imageData) {
    if (imageData == null || imageData.isEmpty) return '';
    try {
      const prefix = 'data:image/jpeg;base64,';
      return imageData.startsWith(prefix)
          ? imageData.substring(prefix.length)
          : imageData;
    } catch (e) {
      return '';
    }
  }
}

class DrawerItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
