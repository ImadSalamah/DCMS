import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'admin_sidebar.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _grandfatherNameController = TextEditingController();
  final _familyNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _idNumberController = TextEditingController();

  String? _role;
  String? _gender;
  DateTime? _birthDate;
  dynamic _patientImage; // يمكن أن يكون File أو Uint8List
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();

  final Map<String, Map<String, String>> _translations = {
    'add_user_title': {'ar': 'إضافة مستخدم جديد', 'en': 'Add New User'},
    'first_name': {'ar': 'الاسم الأول', 'en': 'First Name'},
    'father_name': {'ar': 'اسم الأب', 'en': 'Father Name'},
    'grandfather_name': {'ar': 'اسم الجد', 'en': 'Grandfather Name'},
    'family_name': {'ar': 'اسم العائلة', 'en': 'Family Name'},
    'username': {'ar': 'اسم المستخدم', 'en': 'Username'},
    'birth_date': {'ar': 'تاريخ الميلاد', 'en': 'Birth Date'},
    'gender': {'ar': 'الجنس', 'en': 'Gender'},
    'male': {'ar': 'ذكر', 'en': 'Male'},
    'female': {'ar': 'أنثى', 'en': 'Female'},
    'user_type': {'ar': 'نوع المستخدم', 'en': 'User Type'},
    'admin': {'ar': 'مدير', 'en': 'Admin'},
    'doctor': {'ar': 'طبيب', 'en': 'Doctor'},
    'secretary': {'ar': 'سكرتير', 'en': 'Secretary'},
    'security': {'ar': 'أمن', 'en': 'Security'},
    'phone': {'ar': 'رقم الهاتف', 'en': 'Phone Number'},
    'address': {'ar': 'مكان السكن', 'en': 'Address'},
    'id_number': {'ar': 'رقم الهوية', 'en': 'ID Number'},
    'password': {'ar': 'كلمة المرور', 'en': 'Password'},
    'confirm_password': {'ar': 'تأكيد كلمة المرور', 'en': 'Confirm Password'},
    'add_button': {'ar': 'إضافة المستخدم', 'en': 'Add User'},
    'add_profile_photo': {'ar': 'إضافة صورة شخصية', 'en': 'Add Profile Photo'},
    'personal_info': {'ar': 'المعلومات الشخصية', 'en': 'Personal Information'},
    'account_info': {'ar': 'معلومات الحساب', 'en': 'Account Information'},
    'required_field': {'ar': 'هذا الحقل مطلوب', 'en': 'This field is required'},
    'select_date': {'ar': 'اختر التاريخ', 'en': 'Select date'},
    'validation_required': {'ar': 'هذا الحقل مطلوب', 'en': 'This field is required'},
    'validation_phone_length': {'ar': 'رقم الهاتف يجب أن يكون 10 أرقام', 'en': 'Phone must be 10 digits'},
    'validation_id_length': {'ar': 'رقم الهوية يجب أن يكون 9 أرقام', 'en': 'ID must be 9 digits'},
    'validation_password_length': {'ar': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل', 'en': 'Password must be at least 6 characters'},
    'validation_password_match': {'ar': 'كلمات المرور غير متطابقة', 'en': 'Passwords do not match'},
    'validation_gender': {'ar': 'الرجاء اختيار الجنس', 'en': 'Please select gender'},
    'validation_user_type': {'ar': 'الرجاء اختيار نوع المستخدم', 'en': 'Please select user type'},
    'add_success': {'ar': 'تم إضافة المستخدم بنجاح', 'en': 'User added successfully'},
    'add_error': {'ar': 'حدث خطأ أثناء إضافة المستخدم', 'en': 'Error adding user'},
    'image_error': {'ar': 'حدث خطأ في تحميل الصورة', 'en': 'Image upload error'},
    'username_taken': {'ar': 'اسم المستخدم محجوز', 'en': 'Username already taken'},
    'show_password': {'ar': 'إظهار كلمة المرور', 'en': 'Show password'},
    'hide_password': {'ar': 'إخفاء كلمة المرور', 'en': 'Hide password'},
    'permission_denied': {'ar': 'تم رفض صلاحيات الوصول إلى المعرض', 'en': 'Gallery access denied'},
    'validation_email': {'ar': 'البريد الإلكتروني مستخدم بالفعل', 'en': 'Email already in use'},
  };

  String _translate(String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final languageCode = languageProvider.isEnglish ? 'en' : 'ar';

    // Safely access the translations
    final translationMap = _translations[key];
    if (translationMap == null) {
      debugPrint('Missing translation for key: $key');
      return key; // Return the key as fallback
    }

    final translatedText = translationMap[languageCode];
    return translatedText ?? key; // Return key if translation is null
  }

  Future<bool> _checkPermissions() async {
    if (!kIsWeb) {
      final status = await Permission.photos.status;
      if (status.isDenied) {
        await Permission.photos.request();
      }
      return status.isGranted;
    }
    return true;
  }

  Future<void> _pickImage() async {
    try {
      if (!await _checkPermissions()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_translate('permission_denied'))),
        );
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (!mounted) return;
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          if (!mounted) return;
          setState(() => _patientImage = bytes);
        } else {
          final bytes = await File(image.path).readAsBytes();
          await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 800,
            minHeight: 800,
            quality: 70,
          );
          if (!mounted) return;
          setState(() => _patientImage = File(image.path));
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_translate('image_error')}: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_translate('image_error')}: $e')),
      );
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _birthDate) {
      setState(() => _birthDate = picked);
    }
  }

  Future<bool> _isUsernameUnique(String username) async {
    final snapshot = await _database
        .child('users')
        .orderByChild('username')
        .equalTo(username)
        .once();

    return snapshot.snapshot.value == null;
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate('validation_password_match'))),
      );
      return;
    }

    if (_gender == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate('validation_gender'))),
      );
      return;
    }

    if (_role == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate('validation_user_type'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // التحقق من أن اسم المستخدم فريد
      if (_role != 'patient') {
        final isUnique = await _isUsernameUnique(_usernameController.text.trim());
        if (!isUnique) {
          throw FirebaseAuthException(
            code: 'username-exists',
            message: _translate('username_taken'),
          );
        }
      }

      // تحويل الصورة إلى base64
      String? imageBase64;
      if (_patientImage != null) {
        if (kIsWeb) {
          imageBase64 = base64Encode(_patientImage as Uint8List);
        } else {
          final bytes = await (_patientImage as File).readAsBytes();
          imageBase64 = base64Encode(bytes);
        }
      }

      // إنشاء البريد الإلكتروني التلقائي للموظفين
      final email = _role == 'patient'
          ? '${_usernameController.text.trim()}@patient.com'
          : '${_usernameController.text.trim()}@aaup.edu';

      // إنشاء المستخدم في Firebase Auth
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      // تحضير بيانات المستخدم
      final userData = {
        'firstName': _firstNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'grandfatherName': _grandfatherNameController.text.trim(),
        'familyName': _familyNameController.text.trim(),
        'fullName': '${_firstNameController.text.trim()} ${_fatherNameController.text.trim()} ${_grandfatherNameController.text.trim()} ${_familyNameController.text.trim()}',
        'username': _usernameController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'birthDate': _birthDate?.millisecondsSinceEpoch,
        'gender': _gender,
        'role': _role,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'email': email,
        'image': imageBase64,
        'createdAt': ServerValue.timestamp,
        'isActive': true,
      };

      // حفظ البيانات في Realtime Database
      await _database.child('users/${userCredential.user!.uid}').set(userData);

      // إذا كان موظفاً، نضيفه إلى مجموعة الموظفين
      if (_role != 'patient') {
        await _database.child('staff/${userCredential.user!.uid}').set({
          'uid': userCredential.user!.uid,
          'username': _usernameController.text.trim(),
          'fullName': userData['fullName'],
          'email': email,
          'role': _role,
        });
      }

      // إرسال بريد التحقق
      await userCredential.user?.sendEmailVerification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate('add_success'))),
      );

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String errorMessage = _translate('add_error');
      if (e.code == 'weak-password') {
        errorMessage = _translate('validation_password_length');
      } else if (e.code == 'email-already-in-use') {
        errorMessage = _translate('validation_email');
      } else if (e.code == 'username-exists') {
        errorMessage = _translate('username_taken');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_translate('add_error')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildImageWidget() {
    if (_patientImage == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 50, color: primaryColor),
          const SizedBox(height: 8),
          Text(
            _translate('add_profile_photo'),
            style: TextStyle(color: primaryColor),
          ),
        ],
      );
    }

    try {
      return kIsWeb
          ? Image.memory(
        _patientImage as Uint8List,
        width: 150,
        height: 150,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      )
          : Image.file(
        _patientImage as File,
        width: 150,
        height: 150,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } catch (e) {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 40),
        const SizedBox(height: 8),
        Text(
          _translate('image_error'),
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    Widget? suffixIcon,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: primaryColor.withValues(alpha: 0.8)),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildGenderRadioButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            '${_translate('gender')} ${_translate('required_field')}',
            style: TextStyle(
              color: primaryColor.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: Text(_translate('male')),
                value: 'male',
                groupValue: _gender,
                activeColor: primaryColor,
                onChanged: (value) => setState(() => _gender = value),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: Text(_translate('female')),
                value: 'female',
                groupValue: _gender,
                activeColor: primaryColor,
                onChanged: (value) => setState(() => _gender = value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            '${_translate('user_type')} ${_translate('required_field')}',
            style: TextStyle(
              color: primaryColor.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          value: _role,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: [
            DropdownMenuItem(
              value: 'doctor',
              child: Text(_translate('doctor')),
            ),
            DropdownMenuItem(
              value: 'secretary',
              child: Text(_translate('secretary')),
            ),
            DropdownMenuItem(
              value: 'security',
              child: Text(_translate('security')),
            ),
            DropdownMenuItem(
              value: 'admin',
              child: Text(_translate('admin')),
            ),
          ],
          onChanged: (value) => setState(() => _role = value),
          validator: (value) => value == null ? _translate('validation_user_type') : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(_translate('add_user_title')),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            leading: isLargeScreen ? null : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          drawer: isLargeScreen ? null : AdminSidebar(
            primaryColor: primaryColor,
            accentColor: accentColor,
            userName: null,
            userImageUrl: null,
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
            parentContext: context,
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLargeScreen)
                SizedBox(
                  width: 260,
                  child: AdminSidebar(
                    primaryColor: primaryColor,
                    accentColor: accentColor,
                    userName: null,
                    userImageUrl: null,
                    onLogout: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/');
                      }
                    },
                    parentContext: context,
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // صورة الملف الشخصي
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  border: Border.all(color: primaryColor),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _buildImageWidget(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // قسم المعلومات الشخصية
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _translate('personal_info'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // حقول الأسماء
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextFormField(
                                          controller: _firstNameController,
                                          labelText: '${_translate('first_name')} ${_translate('required_field')}',
                                          prefixIcon: Icon(Icons.person, color: accentColor),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return _translate('validation_required');
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildTextFormField(
                                          controller: _fatherNameController,
                                          labelText: '${_translate('father_name')} ${_translate('required_field')}',
                                          prefixIcon: Icon(Icons.person, color: accentColor),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return _translate('validation_required');
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextFormField(
                                          controller: _grandfatherNameController,
                                          labelText: '${_translate('grandfather_name')} ${_translate('required_field')}',
                                          prefixIcon: Icon(Icons.person, color: accentColor),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return _translate('validation_required');
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildTextFormField(
                                          controller: _familyNameController,
                                          labelText: '${_translate('family_name')} ${_translate('required_field')}',
                                          prefixIcon: Icon(Icons.person, color: accentColor),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return _translate('validation_required');
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),

                                  // اسم المستخدم وتاريخ الميلاد
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextFormField(
                                          controller: _usernameController,
                                          labelText: '${_translate('username')} ${_translate('required_field')}',
                                          prefixIcon: Icon(Icons.person_pin, color: accentColor),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return _translate('validation_required');
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: InkWell(
                                          onTap: _selectBirthDate,
                                          child: InputDecorator(
                                            decoration: InputDecoration(
                                              labelText: '${_translate('birth_date')} ${_translate('required_field')}',
                                              labelStyle: TextStyle(color: primaryColor.withValues(alpha: 0.8)),
                                              prefixIcon: Icon(Icons.calendar_today, color: accentColor),
                                              filled: true,
                                              fillColor: Colors.grey[50],
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                            ),
                                            child: Text(
                                              _birthDate == null
                                                  ? _translate('select_date')
                                                  : DateFormat('yyyy-MM-dd').format(_birthDate!),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: _birthDate == null ? Colors.grey[600] : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),

                                  // حقل الجنس (Radio Buttons)
                                  _buildGenderRadioButtons(),
                                  const SizedBox(height: 15),

                                  // حقل نوع المستخدم (Dropdown)
                                  _buildUserTypeDropdown(),
                                  const SizedBox(height: 15),

                                  // رقم الهاتف
                                  _buildTextFormField(
                                    controller: _phoneController,
                                    labelText: '${_translate('phone')} ${_translate('required_field')}',
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    prefixIcon: Icon(Icons.phone, color: accentColor),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return _translate('validation_required');
                                      }
                                      if (value.length < 10) {
                                        return _translate('validation_phone_length');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 15),

                                  // مكان السكن
                                  _buildTextFormField(
                                    controller: _addressController,
                                    labelText: '${_translate('address')} ${_translate('required_field')}',
                                    prefixIcon: Icon(Icons.location_on, color: accentColor),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return _translate('validation_required');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 15),

                                  // رقم الهوية
                                  _buildTextFormField(
                                    controller: _idNumberController,
                                    labelText: '${_translate('id_number')} ${_translate('required_field')}',
                                    keyboardType: TextInputType.number,
                                    maxLength: 9,
                                    prefixIcon: Icon(Icons.credit_card, color: accentColor),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return _translate('validation_required');
                                      }
                                      if (value.length < 9) {
                                        return _translate('validation_id_length');
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // قسم معلومات الحساب
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _translate('account_info'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // كلمة المرور
                                  _buildTextFormField(
                                    controller: _passwordController,
                                    labelText: '${_translate('password')} ${_translate('required_field')}',
                                    obscureText: !_showPassword,
                                    prefixIcon: Icon(Icons.lock, color: accentColor),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showPassword ? Icons.visibility : Icons.visibility_off,
                                        color: accentColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showPassword = !_showPassword;
                                        });
                                      },
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return _translate('validation_required');
                                      }
                                      if (value.length < 6) {
                                        return _translate('validation_password_length');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 15),

                                  // تأكيد كلمة المرور
                                  _buildTextFormField(
                                    controller: _confirmPasswordController,
                                    labelText: '${_translate('confirm_password')} ${_translate('required_field')}',
                                    obscureText: !_showConfirmPassword,
                                    prefixIcon: Icon(Icons.lock_outline, color: accentColor),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                        color: accentColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showConfirmPassword = !_showConfirmPassword;
                                        });
                                      },
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return _translate('validation_required');
                                      }
                                      if (value != _passwordController.text) {
                                        return _translate('validation_password_match');
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                            // زر الإضافة
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _addUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                  _translate('add_button'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ), // End Expanded
            ], // End children of Row
          ), // End Row
        ); // End Scaffold
      }, // End builder
    ); // End LayoutBuilder
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _fatherNameController.dispose();
    _grandfatherNameController.dispose();
    _familyNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}