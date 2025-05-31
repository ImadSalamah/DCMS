import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ScreeningForm extends StatefulWidget {
  final Map<String, dynamic>? patientData;
  final int? age;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic> data)? onSave;

  const ScreeningForm({
    super.key,
    this.patientData,
    this.age,
    this.initialData,
    this.onSave,
  });

  @override
  _ScreeningFormState createState() => _ScreeningFormState();
}

class _ScreeningFormState extends State<ScreeningForm> {
  final TextEditingController _chiefComplaintController =
      TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _positiveAnswersExplanationController =
      TextEditingController();
  final TextEditingController _preventiveAdviceController =
      TextEditingController();

  late Map<String, int> medicalHistory;
  late Map<String, bool> healthProblems;
  late Map<String, int> dentalHistory;
  late List<Map<String, dynamic>> categories;
  late int _medicationRequiredBeforeDental;
  late int _smokeOrTobacco;

  @override
  void initState() {
    super.initState();

    // Initialize with default values or from initialData
    medicalHistory = {
      'Have there been any changes in your health in the past year?': 0,
      'Are you under the care of a physician?': 0,
      'Have you had any serious illnesses or operations?': 0,
    };

    healthProblems = {
      'Heart Failure': false,
      'Heart Attack': false,
      'Angina': false,
      'Pacemaker': false,
      'Congenital Heart Disease': false,
      'Other Heart Disease': false,
      'Anemia': false,
      'Hemophilia': false,
      'Leukaemia': false,
      'Blood Transfusion': false,
      'Other Blood Disease': false,
      'Asthma': false,
      'Chronic Obstructive Pulmonary Disease': false,
      'Gastro-oesophageal reflux': false,
      'Hepatitis': false,
      'Liver disease': false,
      'Epilepsy': false,
      'Parkinson\'s Disease': false,
      'Kidney Failure': false,
      'Dialysis': false,
      'Drug Allergy': false,
      'Food Allergy': false,
      'Cancer': false,
      'Breast Cancer': false,
      'Lung Cancer': false,
      'Prostate Cancer': false,
      'Colon Cancer': false,
      'Other Cancer': false,
    };

    dentalHistory = {
      'Have you had any serious problem(s) with any previous dental treatment?':
          0,
      'Have you ever had an injury to your face, jaw, or teeth?': 0,
      'Do you ever feel like you have a dry mouth?': 0,
      'Have you ever had an unusual reaction to local anesthetic?': 0,
      'Do you clench your teeth?': 0,
    };

    categories = [
      {'name': 'Lips', 'score': 0},
      {'name': 'Tongue', 'score': 0},
      {'name': 'Gums and Tissues', 'score': 0},
      {'name': 'Saliva', 'score': 0},
      {'name': 'Natural Teeth', 'score': 0},
      {'name': 'Denture(s)', 'score': 0},
      {'name': 'Oral Cleanliness', 'score': 0},
      {'name': 'Dental Pain', 'score': 0},
    ];

    _medicationRequiredBeforeDental = 0;
    _smokeOrTobacco = 0;

    // Load initial data if provided
    if (widget.initialData != null) {
      _loadInitialData(widget.initialData!);
    }
  }

  void _loadInitialData(Map<String, dynamic> data) {
    setState(() {
      _chiefComplaintController.text = data['chiefComplaint'] ?? '';
      _medicationsController.text = data['medications'] ?? '';
      _positiveAnswersExplanationController.text =
          data['positiveAnswersExplanation'] ?? '';
      _preventiveAdviceController.text = data['preventiveAdvice'] ?? '';

      if (data['medicalHistory'] != null) {
        medicalHistory = Map<String, int>.from(data['medicalHistory']);
      }

      if (data['healthProblems'] != null) {
        healthProblems = Map<String, bool>.from(data['healthProblems']);
      }

      if (data['dentalHistory'] != null) {
        dentalHistory = Map<String, int>.from(data['dentalHistory']);
      }

      if (data['categories'] != null) {
        categories = List<Map<String, dynamic>>.from(data['categories']);
      }

      _medicationRequiredBeforeDental =
          data['medicationRequiredBeforeDental'] ?? 0;
      _smokeOrTobacco = data['smokeOrTobacco'] ?? 0;
    });
  }

  Map<String, dynamic> _collectFormData() {
    return {
      'chiefComplaint': _chiefComplaintController.text,
      'medicalHistory': medicalHistory,
      'healthProblems': healthProblems,
      'positiveAnswersExplanation': _positiveAnswersExplanationController.text,
      'medications': _medicationsController.text,
      'medicationRequiredBeforeDental': _medicationRequiredBeforeDental,
      'smokeOrTobacco': _smokeOrTobacco,
      'dentalHistory': dentalHistory,
      'categories': categories,
      'preventiveAdvice': _preventiveAdviceController.text,
      'totalScore': getTotalScore(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  int getTotalScore() {
    return categories.fold(0, (sum, item) => sum + (item['score'] as int));
  }

  Widget _buildPatientInfo() {
    final p = widget.patientData;
    if (p == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p['firstName'] != null && p['familyName'] != null)
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    const TextSpan(
                      text: 'اسم المريض: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${p['firstName']} ${p['familyName']}'),
                  ],
                ),
              ),
            if (widget.age != null)
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    const TextSpan(
                      text: 'العمر: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${widget.age}'),
                  ],
                ),
              ),
            if (p['gender'] != null)
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    const TextSpan(
                      text: 'الجنس: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${p['gender']}'),
                  ],
                ),
              ),
            if (p['phone'] != null)
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    const TextSpan(
                      text: 'الهاتف: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${p['phone']}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Future<void> _saveScreeningToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      return;
    }
    final doctorId = user.uid;
    final patientId =
        widget.patientData != null && widget.patientData!['id'] != null
            ? widget.patientData!['id']
            : null;
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد معرف للمريض')),
      );
      return;
    }
    final formData = _collectFormData();
    final data = {
      'doctorId': doctorId,
      'patientId': patientId,
      'screening': formData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final dbRef = FirebaseDatabase.instance.ref();
    await dbRef.child('examinations').child('examinations').push().set(data);
  }

  void _submitForm() async {
    final formData = _collectFormData();
    if (widget.onSave != null) {
      widget.onSave!(formData);
    }
    await _saveScreeningToDatabase();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ بيانات الفحص المبدئي')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (widget.patientData != null) _buildPatientInfo(),
          _buildSection('Chief Complaint', [
            TextField(
              controller: _chiefComplaintController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter chief complaint...',
              ),
              maxLines: 3,
            ),
          ]),
          _buildSection('Medical History', [
            ...medicalHistory.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<int>(
                            title: const Text('Yes'),
                            value: 1,
                            groupValue: entry.value,
                            onChanged: (value) {
                              setState(() {
                                medicalHistory[entry.key] = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<int>(
                            title: const Text('No'),
                            value: 0,
                            groupValue: entry.value,
                            onChanged: (value) {
                              setState(() {
                                medicalHistory[entry.key] = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                )),
          ]),
          _buildSection('Health Problems', [
            ...healthProblems.entries.map((entry) => CheckboxListTile(
                  title: Text(entry.key),
                  value: entry.value,
                  onChanged: (value) {
                    setState(() {
                      healthProblems[entry.key] = value!;
                    });
                  },
                )),
          ]),
          _buildSection('Please Explain any Positive Answers', [
            TextField(
              controller: _positiveAnswersExplanationController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Explain any positive answers...',
              ),
              maxLines: 3,
            ),
          ]),
          _buildSection('List any Medications you are Currently Taking', [
            TextField(
              controller: _medicationsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'List your current medications...',
              ),
              maxLines: 3,
            ),
          ]),
          _buildSection(
              'Are you taking any medication required before dental treatment?',
              [
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Yes'),
                        value: 1,
                        groupValue: _medicationRequiredBeforeDental,
                        onChanged: (value) {
                          setState(() {
                            _medicationRequiredBeforeDental = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('No'),
                        value: 0,
                        groupValue: _medicationRequiredBeforeDental,
                        onChanged: (value) {
                          setState(() {
                            _medicationRequiredBeforeDental = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ]),
          _buildSection('Do you smoke or use tobacco in any form?', [
            Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    title: const Text('Yes'),
                    value: 1,
                    groupValue: _smokeOrTobacco,
                    onChanged: (value) {
                      setState(() {
                        _smokeOrTobacco = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    title: const Text('No'),
                    value: 0,
                    groupValue: _smokeOrTobacco,
                    onChanged: (value) {
                      setState(() {
                        _smokeOrTobacco = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ]),
          _buildSection('Dental History', [
            ...dentalHistory.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<int>(
                            title: const Text('Yes'),
                            value: 1,
                            groupValue: entry.value,
                            onChanged: (value) {
                              setState(() {
                                dentalHistory[entry.key] = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<int>(
                            title: const Text('No'),
                            value: 0,
                            groupValue: entry.value,
                            onChanged: (value) {
                              setState(() {
                                dentalHistory[entry.key] = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                )),
          ]),
          _buildSection('Oral Health Assessment', [
            ...categories.map((category) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category['name']),
                    Row(
                      children: List.generate(
                          3,
                          (index) => Expanded(
                                child: RadioListTile<int>(
                                  title: Text('$index'),
                                  value: index,
                                  groupValue: category['score'],
                                  onChanged: (value) {
                                    setState(() {
                                      category['score'] = value!;
                                    });
                                  },
                                ),
                              )),
                    ),
                  ],
                )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Total Score: ${getTotalScore()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ]),
          _buildSection('Preventive Advice', [
            TextField(
              controller: _preventiveAdviceController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter preventive advice...',
              ),
              maxLines: 3,
            ),
          ]),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitForm,
            child: const Text('حفظ البيانات'),
          ),
        ],
      ),
    );
  }
}
