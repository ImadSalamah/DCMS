import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AddDentalStudentPage extends StatefulWidget {
  const AddDentalStudentPage({super.key});

  @override
  State<AddDentalStudentPage> createState() => _AddDentalStudentPageState();
}

class _AddDentalStudentPageState extends State<AddDentalStudentPage> {
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
  final _studentIdController = TextEditingController();

  String? _gender;
  DateTime? _birthDate;
  dynamic _profileImage;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Dental Student'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image
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

              // Personal Information Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name Fields
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextFormField(
                            controller: _firstNameController,
                            labelText: 'First Name *',
                            prefixIcon: Icon(Icons.person, color: accentColor),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'This field is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextFormField(
                            controller: _fatherNameController,
                            labelText: 'Father Name *',
                            prefixIcon: Icon(Icons.person, color: accentColor),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'This field is required';
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
                            labelText: 'Grandfather Name *',
                            prefixIcon: Icon(Icons.person, color: accentColor),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'This field is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextFormField(
                            controller: _familyNameController,
                            labelText: 'Family Name *',
                            prefixIcon: Icon(Icons.person, color: accentColor),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'This field is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Username and Birth Date
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextFormField(
                            controller: _usernameController,
                            labelText: 'Username *',
                            prefixIcon: Icon(Icons.person_pin, color: accentColor),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'This field is required';
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
                                labelText: 'Birth Date *',
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
                                    ? 'Select date'
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

                    // Gender Radio Buttons
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Gender *',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Male'),
                                value: 'male',
                                groupValue: _gender,
                                activeColor: primaryColor,
                                onChanged: (value) => setState(() => _gender = value),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Female'),
                                value: 'female',
                                groupValue: _gender,
                                activeColor: primaryColor,
                                onChanged: (value) => setState(() => _gender = value),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Phone Number
                    _buildTextFormField(
                      controller: _phoneController,
                      labelText: 'Phone Number *',
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      prefixIcon: Icon(Icons.phone, color: accentColor),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'This field is required';
                        }
                        if (value.length < 10) {
                          return 'Phone must be 10 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Address
                    _buildTextFormField(
                      controller: _addressController,
                      labelText: 'Address *',
                      prefixIcon: Icon(Icons.location_on, color: accentColor),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'This field is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // ID Number
                    _buildTextFormField(
                      controller: _idNumberController,
                      labelText: 'ID Number *',
                      keyboardType: TextInputType.number,
                      maxLength: 9,
                      prefixIcon: Icon(Icons.credit_card, color: accentColor),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'This field is required';
                        }
                        if (value.length < 9) {
                          return 'ID must be 9 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Student ID
                    _buildTextFormField(
                      controller: _studentIdController,
                      labelText: 'Student ID *',
                      keyboardType: TextInputType.number,
                      maxLength: 9,
                      prefixIcon: Icon(Icons.school, color: accentColor),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'This field is required';
                        }
                        if (value.length < 9) {
                          return 'Student ID must be 9 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Account Information Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password
                    _buildTextFormField(
                      controller: _passwordController,
                      labelText: 'Password *',
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
                          return 'This field is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Confirm Password
                    _buildTextFormField(
                      controller: _confirmPasswordController,
                      labelText: 'Confirm Password *',
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
                          return 'This field is required';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Add Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Add Student',
                    style: TextStyle(
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
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      enabled: enabled,
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

  Widget _buildImageWidget() {
    if (_profileImage == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 50, color: primaryColor),
          const SizedBox(height: 8),
          const Text(
            'Add Profile Photo',
            style: TextStyle(color: Colors.black87),
          ),
        ],
      );
    }

    try {
      return kIsWeb
          ? Image.memory(
        _profileImage as Uint8List,
        width: 150,
        height: 150,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      )
          : Image.file(
        _profileImage as File,
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
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 40),
        SizedBox(height: 8),
        Text(
          'Image Error',
          style: TextStyle(color: Colors.red, fontSize: 12),
        ),
      ],
    );
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
          const SnackBar(content: Text('Gallery access denied')),
        );
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() => _profileImage = bytes);
        } else {
          final bytes = await File(image.path).readAsBytes();
          // Remove unused compressedImage variable
          await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 800,
            minHeight: 800,
            quality: 70,
          );
          setState(() => _profileImage = File(image.path));
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload error: [${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload error: $e')),
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

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if username is unique
      final isUnique = await _isUsernameUnique(_usernameController.text.trim());
      if (!isUnique) {
        throw FirebaseAuthException(
          code: 'username-exists',
          message: 'Username already taken',
        );
      }

      // Convert image to base64
      String? imageBase64;
      if (_profileImage != null) {
        if (kIsWeb) {
          imageBase64 = base64Encode(_profileImage as Uint8List);
        } else {
          final bytes = await (_profileImage as File).readAsBytes();
          imageBase64 = base64Encode(bytes);
        }
      }

      // Create student email
      final email = '${_usernameController.text.trim()}@student.aaup.edu';

      // Create user in Firebase Auth
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // Prepare student data
      final studentData = {
        'firstName': _firstNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'grandfatherName': _grandfatherNameController.text.trim(),
        'familyName': _familyNameController.text.trim(),
        'fullName': '${_firstNameController.text.trim()} ${_fatherNameController.text.trim()} ${_grandfatherNameController.text.trim()} ${_familyNameController.text.trim()}',
        'username': _usernameController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'studentId': _studentIdController.text.trim(),
        'birthDate': _birthDate?.millisecondsSinceEpoch,
        'gender': _gender,
        'role': 'dental_student',
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'email': email,
        'image': imageBase64,
        'createdAt': ServerValue.timestamp,
        'isActive': true,
      };

      // Save data to Realtime Database
      await _database.child('users/${userCredential.user!.uid}').set(studentData);
      await _database.child('students/${userCredential.user!.uid}').set({
        'uid': userCredential.user!.uid,
        'username': _usernameController.text.trim(),
        'fullName': studentData['fullName'],
        'email': email,
        'studentId': _studentIdController.text.trim(),
      });

      // Send verification email
      await userCredential.user?.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student added successfully')),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error adding student';
      if (e.code == 'weak-password') {
        errorMessage = 'Password must be at least 6 characters';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email already in use';
      } else if (e.code == 'username-exists') {
        errorMessage = 'Username already taken';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding student: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    _studentIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}