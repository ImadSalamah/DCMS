import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaedodonticsForm extends StatefulWidget {
  final String groupId;
  final int caseNumber;
  final Map<String, dynamic> patient;
  final String? courseId;
  final Function()? onSave;
  final String? caseType;
  final Map<String, dynamic>? initialData;

  const PaedodonticsForm({
    super.key,
    required this.groupId,
    required this.caseNumber,
    required this.patient,
    this.courseId,
    this.onSave,
    this.caseType,
    this.initialData,
  });

  @override
  State<PaedodonticsForm> createState() => _PaedodonticsFormState();
}

class _PaedodonticsFormState extends State<PaedodonticsForm> {
  bool isSubmitting = false;
  String? lastSubmittedCaseKey;
  String? lastCaseStatus;
  int? lastCaseMark;
  String? lastDoctorComment;

  String guardianName = '';
  String patientAddress = '';
  String patientPhone = '';
  String? diagnosis = '';

  final _formKey = GlobalKey<FormState>();

  final TextEditingController guardianNameController = TextEditingController();
  final TextEditingController patientAddressController = TextEditingController();
  final TextEditingController patientPhoneController = TextEditingController();
  final TextEditingController diagnosisController = TextEditingController();
  final TextEditingController _doctorMarkController = TextEditingController();
  final TextEditingController _doctorNoteController = TextEditingController();

  final Map<String, Map<String, String>> _translations = {
    'clinical_requirements': {'ar': 'المتطلبات السريرية', 'en': 'Clinical Requirements'},
    'history_title': {'ar': 'أخذ التاريخ والفحص والتخطيط', 'en': 'History taking, examination, & treatment planning'},
    'history_required': {'ar': 'المطلوب: 3 حالات', 'en': 'Required: 3 cases'},
    'fissure_title': {'ar': 'سد الشقوق', 'en': 'Fissure sealants'},
    'fissure_required': {'ar': 'المطلوب: 6 حالات', 'en': 'Required: 6 cases'},
    'guardian_name': {'ar': 'اسم ولي الأمر', 'en': "Guardian's Name"},
    'patient_address': {'ar': 'عنوان المريض', 'en': 'Patient Address'},
    'patient_phone': {'ar': 'رقم هاتف المريض', 'en': 'Patient Phone'},
    'send_case': {'ar': 'إرسال الحالة', 'en': 'Submit Case'},
    'last_case_graded': {'ar': 'تم تقييم آخر حالة', 'en': 'Last case graded'},
    'last_case_pending': {'ar': 'آخر حالة قيد المراجعة من الدكتور', 'en': 'Last case pending review'},
    'last_case_rejected': {'ar': 'آخر حالة بحاجة لتعديل', 'en': 'Last case needs revision'},
    'mark': {'ar': 'العلامة', 'en': 'Mark'},
    'doctor_note': {'ar': 'ملاحظة الدكتور', 'en': 'Doctor Note'},
    'no_mark': {'ar': 'بدون علامة', 'en': 'No mark'},
    'submit_success': {'ar': 'تم إرسال الحالة للدكتور المشرف', 'en': 'Case submitted to supervisor'},
    'must_login': {'ar': 'يجب تسجيل الدخول', 'en': 'You must login'},
  };

  String _translate(String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return _translations[key]?[locale] ?? _translations[key]?['en'] ?? key;
  }

  String get _caseTypeLabel {
    switch (widget.caseType) {
      case 'history':
        return _translate('history_title');
      case 'fissure':
        return _translate('fissure_title');
      default:
        return widget.caseType ?? '';
    }
  }

  bool _isDoctorView() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    // يمكنك تعديل هذا الشرط حسب طريقة تخزينك لدور المستخدم في قاعدة البيانات
    return ModalRoute.of(context)?.settings.name?.toLowerCase().contains('doctor') == true;
  }

  // دالة تتحقق من دور المستخدم من قاعدة البيانات
  Future<bool> _isDoctor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final db = FirebaseDatabase.instance.ref();
    final snapshot = await db.child('users').child(user.uid).child('role').get();
    return snapshot.exists && snapshot.value == 'doctor';
  }

  Future<void> _loadCurrentCase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseDatabase.instance.ref('paedodonticsCases');
    final snapshot = await db.orderByChild('studentId').equalTo(user.uid).get();

    if (snapshot.exists) {
      final cases = snapshot.value as Map<dynamic, dynamic>;
      MapEntry<dynamic, dynamic>? latestEntry;
      int latestTimestamp = 0;
      for (final entry in cases.entries) {
        final caseData = entry.value;
        if (caseData['caseNumber'] == widget.caseNumber &&
            caseData['caseType'] == widget.caseType &&
            caseData['groupId'] == widget.groupId) {
          int ts = (caseData['gradedAt'] ?? caseData['submittedAt'] ?? 0) as int;
          if (ts > latestTimestamp) {
            latestTimestamp = ts;
            latestEntry = entry;
          }
        }
      }
      if (latestEntry != null) {
        final caseData = latestEntry.value;
        lastSubmittedCaseKey = latestEntry.key;
        lastCaseStatus = caseData['status'];
        lastCaseMark = caseData['mark'];
        lastDoctorComment = (caseData['rejectionReason'] ?? caseData['doctorComment'] ?? '').toString();
      }
      setState(() {});
    }
  }

  Future<void> submitCase() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_translate('must_login'))));
      setState(() => isSubmitting = false);
      return;
    }
    try {
      final db = FirebaseDatabase.instance.ref();
      String studentName = '';
      final userSnapshot = await db.child('users').child(user.uid).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        studentName = userData['fullName'] ?? userData['name'] ?? user.displayName ?? '';
      } else {
        studentName = user.displayName ?? '';
      }

      final caseData = {
        'studentId': user.uid,
        'studentName': studentName,
        'guardianName': guardianNameController.text,
        'patientAddress': patientAddressController.text,
        'patientPhone': patientPhoneController.text,
        'diagnosis': diagnosisController.text,
        'groupId': widget.groupId,
        'caseNumber': widget.caseNumber,
        'patient': widget.patient,
        if (widget.courseId != null) 'courseId': widget.courseId,
        'caseType': widget.caseType,
        'status': 'pending',
        'mark': null,
        'doctorComment': null,
        'submittedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await db.child('paedodonticsCases').push().set(caseData);
      await _loadCurrentCase();
      setState(() => isSubmitting = false);
      if (widget.onSave != null) widget.onSave!();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_translate('submit_success'))));
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء إرسال الحالة: $e')));
    }
  }

  void _onGradePressed() async {
    if (_doctorMarkController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال العلامة')));
      return;
    }
    final mark = int.tryParse(_doctorMarkController.text);
    if (mark == null || mark < 0 || mark > 35) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('العلامة يجب أن تكون بين 0 و 35')));
      return;
    }
    if (_doctorNoteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ملاحظات الدكتور مطلوبة')));
      return;
    }
    setState(() => isSubmitting = true);
    try {
      final db = FirebaseDatabase.instance.ref();
      await db.child('paedodonticsCases').child(widget.initialData!['key']).update({
        'status': 'graded',
        'mark': mark,
        'doctorComment': _doctorNoteController.text,
        'diagnosis': diagnosisController.text,
        'gradedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() => isSubmitting = false);
      if (widget.onSave != null) widget.onSave!();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التقييم بنجاح')));
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء حفظ التقييم: $e')));
    }
  }

  void _onRejectPressed() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController reasonController = TextEditingController();
        final TextEditingController noteController = TextEditingController();
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'يرجى إدخال سبب الرفض'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'ملاحظات الدكتور (إجباري)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty || noteController.text.trim().isEmpty) return;
                Navigator.of(context).pop(reasonController.text.trim() + '||' + noteController.text.trim());
              },
              child: const Text('رفض'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty || !reason.contains('||')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إدخال سبب الرفض وملاحظات الدكتور')));
      return;
    }
    final parts = reason.split('||');
    final rejectionReason = parts[0];
    final doctorNote = parts[1];
    setState(() => isSubmitting = true);
    try {
      final db = FirebaseDatabase.instance.ref();
      await db.child('paedodonticsCases').child(widget.initialData!['key']).update({
        'status': 'rejected',
        'doctorComment': doctorNote,
        'rejectionReason': rejectionReason,
        'diagnosis': diagnosisController.text,
        'mark': null,
        'gradedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() => isSubmitting = false);
      if (widget.onSave != null) widget.onSave!();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الحالة وإرجاعها للطالب')));
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء رفض الحالة: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      guardianNameController.text = data['guardianName'] ?? '';
      patientAddressController.text = data['patientAddress'] ?? '';
      patientPhoneController.text = data['patientPhone'] ?? '';
      diagnosisController.text = data['diagnosis'] ?? '';
      lastCaseStatus = data['status'];
      lastCaseMark = data['doctorGrade'] ?? data['mark'];
      lastDoctorComment = (data['rejectionReason'] ?? data['doctorComment'] ?? '').toString();
      if (data['mark'] != null) _doctorMarkController.text = data['mark'].toString();
      if (data['doctorComment'] != null) _doctorNoteController.text = data['doctorComment'];
    }
    _loadCurrentCase();
  }

  @override
  void dispose() {
    guardianNameController.dispose();
    patientAddressController.dispose();
    patientPhoneController.dispose();
    diagnosisController.dispose();
    _doctorMarkController.dispose();
    _doctorNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_caseTypeLabel} ${widget.caseNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // معلومات الحالة
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Text(
                  'نوع الحالة: ${_caseTypeLabel}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // معلومات المريض
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معلومات المريض:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPatientInfoRow('الاسم', widget.patient['fullName'] ?? ''),
                    _buildPatientInfoRow('رقم الهوية', widget.patient['idNumber'] ?? ''),
                    if (widget.patient['studentId'] != null)
                      _buildPatientInfoRow('الرقم الجامعي', widget.patient['studentId']),
                  ],
                ),
              ),
              
              // حقول النموذج
              TextFormField(
                controller: guardianNameController,
                decoration: InputDecoration(
                  labelText: _translate('guardian_name'),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'يجب إدخال اسم ولي الأمر' : null,
                onChanged: (v) => setState(() => guardianName = v),
                enabled: lastCaseStatus != 'pending' && lastCaseStatus != 'graded' && lastCaseStatus != 'pending_review',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: patientAddressController,
                decoration: InputDecoration(
                  labelText: _translate('patient_address'),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'يجب إدخال عنوان المريض' : null,
                onChanged: (v) => setState(() => patientAddress = v),
                enabled: lastCaseStatus != 'pending' && lastCaseStatus != 'graded' && lastCaseStatus != 'pending_review',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: patientPhoneController,
                decoration: InputDecoration(
                  labelText: _translate('patient_phone'),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'يجب إدخال رقم الهاتف' : null,
                onChanged: (v) => setState(() => patientPhone = v),
                enabled: lastCaseStatus != 'pending' && lastCaseStatus != 'graded' && lastCaseStatus != 'pending_review',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: diagnosisController,
                decoration: InputDecoration(
                  labelText: 'التشخيص',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                onChanged: (v) => setState(() {}),
                enabled: lastCaseStatus != 'pending' && lastCaseStatus != 'graded' && lastCaseStatus != 'pending_review',
              ),
              const SizedBox(height: 24),
              
              // حالة التقييم - تظهر للجميع
              if (lastCaseStatus != null) _buildCaseStatusSection(),

              // حقول التقييم للدكتور تظهر فقط إذا الحالة pending والمستخدم دكتور فعلياً من قاعدة البيانات
              FutureBuilder<bool>(
                future: _isDoctor(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData || !snapshot.data!) {
                    return const SizedBox.shrink();
                  }
                  if (lastCaseStatus == 'pending' && widget.initialData != null) {
                    return Column(
                      children: [
                        const Divider(height: 32),
                        Text('تقييم الدكتور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _doctorMarkController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'العلامة (من 35)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'الرجاء إدخال العلامة';
                            final mark = int.tryParse(value);
                            if (mark == null || mark < 0 || mark > 35) return 'العلامة يجب أن تكون بين 0 و 35';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _doctorNoteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'ملاحظات الدكتور (اختياري)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('حفظ التقييم'),
                                onPressed: isSubmitting ? null : _onGradePressed,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('رفض الحالة'),
                                onPressed: isSubmitting ? null : _onRejectPressed,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('لا يمكن إغلاق النافذة إلا بعد تقييم الحالة أو رفضها مع ذكر السبب.',
                          style: TextStyle(color: Colors.orange, fontSize: 13)),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // زر الإرسال - يظهر فقط للطالب إذا لم تكن الحالة pending أو graded
              if (lastCaseStatus != 'pending' && lastCaseStatus != 'graded' && !_isDoctorView())
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isSubmitting ? null : submitCase,
                    child: isSubmitting
                        ? const CircularProgressIndicator()
                        : Text(
                            _translate('send_case'),
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildCaseStatusSection() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String? rejectionReason;

    if (lastCaseStatus == 'graded') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = _translate('last_case_graded');
    } else if (lastCaseStatus == 'pending') {
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
      statusText = _translate('last_case_pending');
    } else if (lastCaseStatus == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = _translate('last_case_rejected');
      rejectionReason = lastDoctorComment;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = _translate('last_case_rejected');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 16,
                  ),
                ),
              ),
              if (lastCaseStatus == 'graded' && lastCaseMark != null) ...[
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '$lastCaseMark',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (lastDoctorComment != null && lastDoctorComment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ملاحظات الدكتور: $lastDoctorComment',
                      style: const TextStyle(color: Colors.blue, fontSize: 15, fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (lastCaseStatus == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سبب الرفض: $rejectionReason',
                      style: const TextStyle(color: Colors.orange, fontSize: 15, fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}