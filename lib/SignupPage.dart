import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'package:flutter/services.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _grandfatherNameController = TextEditingController();
  final _familyNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _birthDate;
  String? _gender;
  dynamic _patientImage;
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();

  final Map<String, Map<String, String>> _translations = {
    'signup_title': {'ar': 'إنشاء حساب جديد', 'en': 'Create New Account'},
    'first_name': {'ar': 'الاسم الأول', 'en': 'First Name'},
    'father_name': {'ar': 'اسم الأب', 'en': 'Father Name'},
    'grandfather_name': {'ar': 'اسم الجد', 'en': 'Grandfather Name'},
    'family_name': {'ar': 'اسم العائلة', 'en': 'Family Name'},
    'id_number': {'ar': 'رقم الهوية', 'en': 'ID Number'},
    'birth_date': {'ar': 'تاريخ الميلاد', 'en': 'Birth Date'},
    'gender': {'ar': 'الجنس', 'en': 'Gender'},
    'male': {'ar': 'ذكر', 'en': 'Male'},
    'female': {'ar': 'أنثى', 'en': 'Female'},
    'phone': {'ar': 'رقم الهاتف', 'en': 'Phone Number'},
    'address': {'ar': 'مكان السكن', 'en': 'Address'},
    'email': {'ar': 'البريد الإلكتروني', 'en': 'Email'},
    'password': {'ar': 'كلمة المرور', 'en': 'Password'},
    'confirm_password': {'ar': 'تأكيد كلمة المرور', 'en': 'Confirm Password'},
    'register_button': {'ar': 'تسجيل الحساب', 'en': 'Register'},
    'add_profile_photo': {'ar': 'إضافة صورة شخصية', 'en': 'Add Profile Photo'},
    'personal_info': {'ar': 'المعلومات الشخصية', 'en': 'Personal Information'},
    'account_info': {'ar': 'معلومات الحساب', 'en': 'Account Information'},
    'required_field': {'ar': '*', 'en': '*'},
    'select_date': {'ar': 'اختر التاريخ', 'en': 'Select date'},
    'validation_required': {
      'ar': 'هذا الحقل مطلوب',
      'en': 'This field is required',
    },
    'validation_id_length': {
      'ar': 'رقم الهوية يجب أن يكون 9 أرقام',
      'en': 'ID must be 9 digits',
    },
    'validation_phone_length': {
      'ar': 'رقم الهاتف يجب أن يكون 10 أرقام',
      'en': 'Phone must be 10 digits',
    },
    'validation_email': {
      'ar': 'البريد الإلكتروني غير صحيح',
      'en': 'Invalid email format',
    },
    'validation_password_length': {
      'ar': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
      'en': 'Password must be at least 6 characters',
    },
    'validation_password_match': {
      'ar': 'كلمات المرور غير متطابقة',
      'en': 'Passwords do not match',
    },
    'validation_gender': {
      'ar': 'الرجاء اختيار الجنس',
      'en': 'Please select gender',
    },
    'register_success': {
      'ar': 'تم التسجيل بنجاح',
      'en': 'Registration successful',
    },
    'register_error': {
      'ar': 'حدث خطأ أثناء التسجيل',
      'en': 'Registration error',
    },
    'image_error': {
      'ar': 'حدث خطأ في تحميل الصورة',
      'en': 'Image upload error',
    },
    'id_exists': {
      'ar': 'رقم الهوية مسجل مسبقاً',
      'en': 'ID number already exists',
    },
    'new_account_notification': {
      'ar': 'حساب جديد يحتاج إلى موافقة',
      'en': 'New account needs approval',
    },
    'account_pending': {
      'ar': 'تم التسجيل بنجاح، ينتظر موافقة المسؤول',
      'en': 'Registration successful, waiting for admin approval',
    },
  };

  String _translate(String key) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    return _translations[key]![languageProvider.isEnglish ? 'en' : 'ar'] ?? key;
  }

  Future<bool> _checkIdNumberExists(String idNumber) async {
    try {
      final activeSnapshot =
          await _database
              .child('users')
              .orderByChild('idNumber')
              .equalTo(idNumber)
              .once();
      if (activeSnapshot.snapshot.value != null) return true;

      final pendingSnapshot =
          await _database
              .child('pendingUsers')
              .orderByChild('idNumber')
              .equalTo(idNumber)
              .once();
      return pendingSnapshot.snapshot.value != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendNotificationToSecretary(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final secretarySnapshot =
          await _database
              .child('users')
              .orderByChild('role')
              .equalTo('secretary')
              .once();

      if (secretarySnapshot.snapshot.value != null) {
        final Map<dynamic, dynamic> secretaries =
            secretarySnapshot.snapshot.value as Map<dynamic, dynamic>;
        final String secretaryId = secretaries.keys.first;

        final notificationRef =
            _database.child('notifications/$secretaryId').push();
        await notificationRef.set({
          'title': _translate('new_account_notification'),
          'message':
              '${userData['firstName']} ${userData['familyName']} - ${userData['idNumber']}',
          'userId': userId,
          'userData': userData,
          'timestamp': ServerValue.timestamp,
          'read': false,
          'type': 'new_account',
        });
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() => _patientImage = bytes);
        } else {
          setState(() => _patientImage = File(image.path));
        }
      }
    } catch (e) {
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

  Future<String?> _uploadImageToRealtimeDB(String userId) async {
    if (_patientImage == null) return null;

    try {
      Uint8List imageBytes =
          kIsWeb
              ? _patientImage as Uint8List
              : await (_patientImage as File).readAsBytes();

      final compressedImage = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 800,
        minHeight: 800,
        quality: 70,
      );

      if (compressedImage.lengthInBytes > 1 * 1024 * 1024) {
        throw Exception('Image size exceeds 1MB limit');
      }

      final base64Image = base64Encode(compressedImage);
      await _database.child('pendingUsers/$userId/image').set(base64Image);
      return base64Image;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_translate('image_error')}: $e')),
      );
      return null;
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate('validation_password_match'))),
      );
      return;
    }

    if (_gender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_translate('validation_gender'))));
      return;
    }

    final idExists = await _checkIdNumberExists(
      _idNumberController.text.trim(),
    );
    if (idExists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_translate('id_exists'))));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String? imageBase64 = await _uploadImageToRealtimeDB(
        userCredential.user!.uid,
      );

      final userData = {
        'firstName': _firstNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'grandfatherName': _grandfatherNameController.text.trim(),
        'familyName': _familyNameController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'birthDate':
            _birthDate?.millisecondsSinceEpoch,
        'gender': _gender,
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'image': imageBase64,
        'createdAt': ServerValue.timestamp,
        'role': 'patient',
        'authUid': userCredential.user!.uid,
        'status': 'active',
      };

      await _database
          .child('pendingUsers/${userCredential.user!.uid}')
          .set(userData);

      await _sendNotificationToSecretary(userCredential.user!.uid, userData);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_translate('account_pending'))));

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String errorMessage = _translate('register_error');
      if (e.code == 'weak-password') {
        errorMessage = _translate('validation_password_length');
      } else if (e.code == 'email-already-in-use') {
        errorMessage = _translate('validation_email');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_translate('register_error')}: $e')),
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

    return kIsWeb
        ? Image.memory(
          _patientImage as Uint8List,
          width: 150,
          height: 150,
          fit: BoxFit.cover,
        )
        : Image.file(
          _patientImage as File,
          width: 150,
          height: 150,
          fit: BoxFit.cover,
        );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: primaryColor.withOpacity(0.8)),
        prefixIcon: prefixIcon,
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
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
              color: primaryColor.withOpacity(0.8),
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection:
          languageProvider.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_translate('signup_title')),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.language),
              onPressed: () {
                languageProvider.toggleLanguage();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
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

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextFormField(
                              controller: _firstNameController,
                              labelText:
                                  '${_translate('first_name')} ${_translate('required_field')}',
                              prefixIcon: Icon(
                                Icons.person,
                                color: accentColor,
                              ),
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
                              labelText:
                                  '${_translate('father_name')} ${_translate('required_field')}',
                              prefixIcon: Icon(
                                Icons.person,
                                color: accentColor,
                              ),
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
                              labelText:
                                  '${_translate('grandfather_name')} ${_translate('required_field')}',
                              prefixIcon: Icon(
                                Icons.person,
                                color: accentColor,
                              ),
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
                              labelText:
                                  '${_translate('family_name')} ${_translate('required_field')}',
                              prefixIcon: Icon(
                                Icons.person,
                                color: accentColor,
                              ),
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
                              controller: _idNumberController,
                              labelText:
                                  '${_translate('id_number')} ${_translate('required_field')}',
                              keyboardType: TextInputType.number,
                              maxLength: 9,
                              prefixIcon: Icon(
                                Icons.credit_card,
                                color: accentColor,
                              ),
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: _selectBirthDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText:
                                      '${_translate('birth_date')} ${_translate('required_field')}',
                                  labelStyle: TextStyle(
                                    color: primaryColor.withOpacity(0.8),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.calendar_today,
                                    color: accentColor,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                ),
                                child: Text(
                                  _birthDate == null
                                      ? _translate('select_date')
                                      : DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(_birthDate!),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        _birthDate == null
                                            ? Colors.grey[600]
                                            : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      _buildGenderRadioButtons(),
                      const SizedBox(height: 15),

                      _buildTextFormField(
                        controller: _phoneController,
                        labelText:
                            '${_translate('phone')} ${_translate('required_field')}',
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

                      _buildTextFormField(
                        controller: _addressController,
                        labelText:
                            '${_translate('address')} ${_translate('required_field')}',
                        prefixIcon: Icon(Icons.location_on, color: accentColor),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return _translate('validation_required');
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

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

                      _buildTextFormField(
                        controller: _emailController,
                        labelText:
                            '${_translate('email')} ${_translate('required_field')}',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icon(Icons.email, color: accentColor),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return _translate('validation_required');
                          }
                          if (!value.contains('@')) {
                            return _translate('validation_email');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      _buildTextFormField(
                        controller: _passwordController,
                        labelText:
                            '${_translate('password')} ${_translate('required_field')}',
                        obscureText: true,
                        prefixIcon: Icon(Icons.lock, color: accentColor),
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

                      _buildTextFormField(
                        controller: _confirmPasswordController,
                        labelText:
                            '${_translate('confirm_password')} ${_translate('required_field')}',
                        obscureText: true,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: accentColor,
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

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : Text(
                              _translate('register_button'),
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
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _fatherNameController.dispose();
    _grandfatherNameController.dispose();
    _familyNameController.dispose();
    _idNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
