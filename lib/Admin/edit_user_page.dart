import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class EditUserPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>>? usersList; // قائمة المستخدمين (اختياري)
  const EditUserPage({super.key, required this.user, this.usersList});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController firstNameController;
  late TextEditingController fatherNameController;
  late TextEditingController grandfatherNameController;
  late TextEditingController familyNameController;
  late TextEditingController usernameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController idNumberController;
  late TextEditingController permissionsController;
  DateTime? birthDate;
  String? gender;
  String? role;
  dynamic userImage;
  bool isSaving = false;
  bool? isActive;

  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    firstNameController =
        TextEditingController(text: widget.user['firstName'] ?? '');
    fatherNameController =
        TextEditingController(text: widget.user['fatherName'] ?? '');
    grandfatherNameController =
        TextEditingController(text: widget.user['grandfatherName'] ?? '');
    familyNameController =
        TextEditingController(text: widget.user['familyName'] ?? '');
    usernameController =
        TextEditingController(text: widget.user['username'] ?? '');
    phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    addressController =
        TextEditingController(text: widget.user['address'] ?? '');
    idNumberController =
        TextEditingController(text: widget.user['idNumber'] ?? '');
    permissionsController =
        TextEditingController(text: widget.user['permissions'] ?? '');
    birthDate = widget.user['birthDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(widget.user['birthDate'])
        : null;
    gender = widget.user['gender']?.toString();
    role = widget.user['role']?.toString();
    isActive = widget.user['isActive'] == null
        ? true
        : widget.user['isActive'] == true || widget.user['isActive'] == 1;
    if (widget.user['image'] != null &&
        widget.user['image'].toString().isNotEmpty) {
      if (kIsWeb) {
        userImage = base64Decode(widget.user['image']);
      } else {
        userImage = base64Decode(widget.user['image']);
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    fatherNameController.dispose();
    grandfatherNameController.dispose();
    familyNameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    idNumberController.dispose();
    permissionsController.dispose();
    super.dispose();
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
          const SnackBar(content: Text('تم رفض صلاحيات الوصول إلى المعرض')),
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
          setState(() => userImage = bytes);
        } else {
          final bytes = await File(image.path).readAsBytes();
          await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 800,
            minHeight: 800,
            quality: 70,
          );
          setState(() => userImage = File(image.path));
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ في تحميل الصورة: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ في تحميل الصورة: $e')),
      );
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime.now(),
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
    if (picked != null && picked != birthDate) {
      setState(() => birthDate = picked);
    }
  }

  Future<void> saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isSaving = true;
    });
    String? imageBase64;
    if (userImage != null) {
      if (kIsWeb) {
        imageBase64 = base64Encode(userImage as Uint8List);
      } else if (userImage is File) {
        final bytes = await (userImage as File).readAsBytes();
        imageBase64 = base64Encode(bytes);
      }
    }
    final DatabaseReference userRef =
        FirebaseDatabase.instance.ref('users/${widget.user['uid']}');
    await userRef.update({
      'firstName': firstNameController.text.trim(),
      'fatherName': fatherNameController.text.trim(),
      'grandfatherName': grandfatherNameController.text.trim(),
      'familyName': familyNameController.text.trim(),
      'username': usernameController.text.trim(),
      'idNumber': idNumberController.text.trim(),
      'birthDate': birthDate?.millisecondsSinceEpoch,
      'gender': gender,
      'role': role,
      'phone': phoneController.text.trim(),
      'address': addressController.text.trim(),
      'permissions': permissionsController.text.trim(),
      'image': imageBase64 ?? '',
      'isActive': isActive == true ? 1 : 0,
    });
    setState(() {
      isSaving = false;
    });
    Navigator.pop(context, true);
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
          title: const Text('تعديل بيانات المستخدم'),
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
        body: Row(
          children: [
            if (widget.usersList != null && widget.usersList!.isNotEmpty)
              Container(
                width: 260,
                color: Colors.grey[100],
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('قائمة المستخدمين',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    ...widget.usersList!.map((u) {
                      final fullName = [
                        u['firstName'],
                        u['fatherName'],
                        u['grandfatherName'],
                        u['familyName'],
                      ]
                          .where((part) =>
                              part != null && part.toString().isNotEmpty)
                          .join(' ');
                      return ListTile(
                        title: Text(fullName),
                        subtitle: Text(u['email']?.toString() ?? ''),
                        onTap: () {
                          setState(() {
                            // عند اختيار مستخدم، حدث جميع الحقول
                            firstNameController.text = u['firstName'] ?? '';
                            fatherNameController.text = u['fatherName'] ?? '';
                            grandfatherNameController.text =
                                u['grandfatherName'] ?? '';
                            familyNameController.text = u['familyName'] ?? '';
                            usernameController.text = u['username'] ?? '';
                            phoneController.text = u['phone'] ?? '';
                            addressController.text = u['address'] ?? '';
                            idNumberController.text = u['idNumber'] ?? '';
                            permissionsController.text = u['permissions'] ?? '';
                            birthDate = u['birthDate'] != null
                                ? DateTime.fromMillisecondsSinceEpoch(
                                    u['birthDate'])
                                : null;
                            gender = u['gender']?.toString();
                            role = u['role']?.toString();
                            isActive = u['isActive'] == null
                                ? true
                                : u['isActive'] == true || u['isActive'] == 1;
                            userImage = (u['image'] != null &&
                                    u['image'].toString().isNotEmpty)
                                ? base64Decode(u['image'])
                                : null;
                          });
                        },
                        selected:
                            usernameController.text == (u['username'] ?? ''),
                      );
                    }),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
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
                            child: userImage == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo,
                                          size: 50, color: primaryColor),
                                      const SizedBox(height: 8),
                                      Text('إضافة صورة شخصية',
                                          style:
                                              TextStyle(color: primaryColor)),
                                    ],
                                  )
                                : (kIsWeb
                                    ? Image.memory(
                                        userImage as Uint8List,
                                        width: 150,
                                        height: 150,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.error_outline,
                                                color: Colors.red, size: 40),
                                            SizedBox(height: 8),
                                            Text('حدث خطأ في تحميل الصورة',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      )
                                    : (userImage is File
                                        ? Image.file(
                                            userImage as File,
                                            width: 150,
                                            height: 150,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.error_outline,
                                                    color: Colors.red,
                                                    size: 40),
                                                SizedBox(height: 8),
                                                Text('حدث خطأ في تحميل الصورة',
                                                    style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          )
                                        : Image.memory(
                                            userImage as Uint8List,
                                            width: 150,
                                            height: 150,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.error_outline,
                                                    color: Colors.red,
                                                    size: 40),
                                                SizedBox(height: 8),
                                                Text('حدث خطأ في تحميل الصورة',
                                                    style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          ))),
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
                            const Text(
                              'المعلومات الشخصية',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: firstNameController,
                                    decoration: InputDecoration(
                                      labelText: 'الاسم الأول *',
                                      prefixIcon: Icon(Icons.person,
                                          color: accentColor),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'هذا الحقل مطلوب'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: fatherNameController,
                                    decoration: InputDecoration(
                                      labelText: 'اسم الأب *',
                                      prefixIcon: Icon(Icons.person,
                                          color: accentColor),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'هذا الحقل مطلوب'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: grandfatherNameController,
                                    decoration: InputDecoration(
                                      labelText: 'اسم الجد *',
                                      prefixIcon: Icon(Icons.person,
                                          color: accentColor),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'هذا الحقل مطلوب'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: familyNameController,
                                    decoration: InputDecoration(
                                      labelText: 'اسم العائلة *',
                                      prefixIcon: Icon(Icons.person,
                                          color: accentColor),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'هذا الحقل مطلوب'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: usernameController,
                                    decoration: InputDecoration(
                                      labelText: 'اسم المستخدم *',
                                      prefixIcon: Icon(Icons.person_pin,
                                          color: accentColor),
                                    ),
                                    validator: (value) {
                                      // إذا كان الدور مريض، لا تجعل الحقل مطلوبًا
                                      if (role == 'patient') return null;
                                      if (value == null || value.isEmpty) {
                                        return 'هذا الحقل مطلوب';
                                      }
                                      return null;
                                    },
                                    enabled: role !=
                                        'patient', // اجعل الحقل غير قابل للتعديل إذا كان مريض
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectBirthDate,
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'تاريخ الميلاد *',
                                        prefixIcon: Icon(Icons.calendar_today,
                                            color: accentColor),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 16, horizontal: 16),
                                      ),
                                      child: Text(
                                        birthDate == null
                                            ? 'اختر التاريخ'
                                            : DateFormat('yyyy-MM-dd')
                                                .format(birthDate!),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: birthDate == null
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
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: gender,
                                    decoration: InputDecoration(
                                      labelText: 'الجنس *',
                                      prefixIcon:
                                          Icon(Icons.wc, color: accentColor),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 16),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'male', child: Text('ذكر')),
                                      DropdownMenuItem(
                                          value: 'female', child: Text('أنثى')),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => gender = value),
                                    validator: (value) => value == null
                                        ? 'الرجاء اختيار الجنس'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: role,
                                    decoration: InputDecoration(
                                      labelText: 'نوع المستخدم *',
                                      prefixIcon: Icon(
                                          Icons.admin_panel_settings,
                                          color: accentColor),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 16),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'doctor', child: Text('طبيب')),
                                      DropdownMenuItem(
                                          value: 'secretary',
                                          child: Text('سكرتير')),
                                      DropdownMenuItem(
                                          value: 'security',
                                          child: Text('أمن')),
                                      DropdownMenuItem(
                                          value: 'admin', child: Text('مدير')),
                                      DropdownMenuItem(
                                          value: 'dental_student',
                                          child: Text('طالب طب أسنان')),
                                      DropdownMenuItem(
                                          value: 'patient',
                                          child: Text('مريض')),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => role = value),
                                    validator: (value) => value == null
                                        ? 'الرجاء اختيار نوع المستخدم'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: phoneController,
                              decoration: InputDecoration(
                                labelText: 'رقم الهاتف *',
                                prefixIcon:
                                    Icon(Icons.phone, color: accentColor),
                              ),
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'هذا الحقل مطلوب';
                                }
                                if (value.length < 10) {
                                  return 'رقم الهاتف يجب أن يكون 10 أرقام';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: addressController,
                              decoration: InputDecoration(
                                labelText: 'مكان السكن *',
                                prefixIcon:
                                    Icon(Icons.location_on, color: accentColor),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'هذا الحقل مطلوب'
                                      : null,
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: idNumberController,
                              decoration: InputDecoration(
                                labelText: 'رقم الهوية *',
                                prefixIcon:
                                    Icon(Icons.credit_card, color: accentColor),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 9,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'هذا الحقل مطلوب';
                                }
                                if (value.length < 9) {
                                  return 'رقم الهوية يجب أن يكون 9 أرقام';
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
                            const Text(
                              'معلومات الحساب',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: permissionsController,
                              decoration: InputDecoration(
                                labelText: 'الصلاحيات',
                                prefixIcon:
                                    Icon(Icons.security, color: accentColor),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Text('حالة الحساب:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 16),
                                  Switch(
                                    value: isActive ?? true,
                                    activeColor: primaryColor,
                                    onChanged: (val) {
                                      setState(() {
                                        isActive = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isActive == true ? 'فعال' : 'غير فعال',
                                      style: TextStyle(
                                          color: isActive == true
                                              ? Colors.green
                                              : Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : saveUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'حفظ التعديلات',
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
            ),
          ],
        ),
      ),
    );
  }
}
