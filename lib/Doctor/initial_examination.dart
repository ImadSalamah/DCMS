import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';
import 'svg.dart';
import 'ScreeningForm.dart';

class InitialExamination extends StatefulWidget {
  final Map<String, dynamic>? patientData;
  final int? age;
  final String doctorId;

  const InitialExamination({
    super.key,
    this.patientData,
    this.age,
    required this.doctorId,
  });

  @override
  State<InitialExamination> createState() => _InitialExaminationState();
}

class _InitialExaminationState extends State<InitialExamination> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, dynamic> _examData = {
    'tmj': 'Normal',
    'lymphNode': 'Normal',
    'patientProfile': 'Straight',
    'lipCompetency': 'Competent',
    'incisalClassification': 'Class I',
    'overjet': 'Normal',
    'overbite': 'Normal',
    'hardPalate': 'Normal',
    'buccalMucosa': 'Normal',
    'floorOfMouth': 'Normal',
    'edentulousRidge': 'Well-developed ridge',
    'periodontalRisk': 'Low',
    'periodontalChart': {
      'Upper right posterior': 0,
      'Upper anterior': 0,
      'Upper left posterior': 0,
      'Lower right posterior': 0,
      'Lower anterior': 0,
      'Lower left posterior': 0,
    },
    'dentalChart': {
      'selectedTeeth': <String>[],
      'teethConditions': <String, String>{},
    }
  };

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<String, Color> _teethColors = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.patientData != null && widget.patientData!['dentalChart'] != null) {
      final dentalChart = widget.patientData!['dentalChart'] as Map<String, dynamic>?;
      if (dentalChart != null) {
        final selectedTeeth = dentalChart['selectedTeeth'] as List<dynamic>?;
        if (selectedTeeth != null) {
          _examData['dentalChart']['selectedTeeth'] = selectedTeeth.map((e) => e.toString()).toList();
        }

        final conditions = dentalChart['teethConditions'] as Map<String, dynamic>?;
        if (conditions != null) {
          _teethColors = conditions.map((key, value) {
            if (value != null) {
              return MapEntry(key, Color(int.parse(value.toString(), radix: 16)));
            }
            return MapEntry(key, Colors.white);
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateExamData(String key, dynamic value) {
    setState(() => _examData[key] = value);
  }

  void _updateChart(String area, int value) {
    setState(() => _examData['periodontalChart'][area] = value);
  }

  void _updateDentalChart(List<String> selectedTeeth) {
    setState(() {
      _examData['dentalChart']['selectedTeeth'] = selectedTeeth;
      _examData['dentalChart']['teethConditions'] =
          _teethColors.map((key, value) => MapEntry(key, value.value.toRadixString(16).padLeft(8, '0')));
    });
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
              Text('Patient: \\${p['firstName']} \\${p['familyName']}'),
            if (widget.age != null) Text('Age: \\${widget.age}'),
            if (p['gender'] != null) Text('Gender: \\${p['gender']}'),
            if (p['phone'] != null) Text('Phone: \\${p['phone']}'),
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
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  Widget _buildRadioGroup({
    required String title,
    required List<String> options,
    required String key,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ...options.map((option) => RadioListTile<String>(
        title: Text(option),
        value: option,
        groupValue: _examData[key] as String? ?? '',
        onChanged: (v) => v != null ? _updateExamData(key, v) : null,
      )),
    ],
  );

  Widget _buildPeriodontalChart() => Column(
    children: [
      ...(_examData['periodontalChart'] as Map<String, dynamic>).entries.map((entry) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key),
              Row(children: List.generate(5, (index) => Expanded(
                child: RadioListTile<int>(
                  title: Text('$index'),
                  value: index,
                  groupValue: entry.value as int? ?? 0,
                  onChanged: (v) => v != null ? _updateChart(entry.key, v) : null,
                ),
              ))),
            ],
          ),
        ),
      )),
      _buildRadioGroup(
        title: 'The periodontal risk assessment',
        options: ['Low', 'Moderate', 'High'],
        key: 'periodontalRisk',
      ),
    ],
  );

  Widget _buildDentalChart() => Column(
    children: [
      SizedBox(
 height: 600, // Maintain the overall height of the container
        child: FittedBox(
          fit: BoxFit.contain, // Scale the content to fit within the container
          child: TeethSelector(
 age: widget.age,
 onChange: (selectedTeeth) {
 _updateDentalChart(selectedTeeth.cast<String>());
 },
 initiallySelected: (_examData['dentalChart']['selectedTeeth'] as List<dynamic>?)?.cast<String>() ?? [],
 colorized: _teethColors,
 onColorUpdate: (colors) {
 _teethColors = colors;
 },
 ),
        ),
      ),
      const SizedBox(height: 16),
      _buildTeethConditionsLegend(),
    ],
  );

  Widget _buildTeethConditionsLegend() {
    final conditions = {
      'سليم': Colors.white,
      'تسوس': const Color(0xFF8B4513),
      'التهاب': Colors.red,
      'كسر': Colors.blueGrey,
      'حشوة': const Color(0xFFFFD700),
      'حشوة مؤقتة': const Color(0xFFFFFF00),
      'سن مفقود': Colors.black,
      'جسر': const Color(0xFFA020F0),
      'زرع': const Color(0xFF00FF00),
      'تلبيسة': const Color(0xFFFFA500),
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: conditions.entries.map((entry) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: entry.value,
                  border: Border.all(color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              Text(entry.key),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _submitExamination() async {
    try {
      final patientId = widget.patientData?['id'];
      if (patientId == null) {
        throw Exception('Patient ID is null');
      }
      final examRecord = {
        'patientId': patientId,
        'doctorId': widget.doctorId,
        'timestamp': ServerValue.timestamp,
        'examData': _examData,
      };
      await _database.child('examinations').push().set(examRecord);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Examination saved successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Widget _buildScreeningFormTab() {
    return ScreeningForm(
      patientData: widget.patientData,
      age: widget.age,
      onSave: (screeningData) {
        // Store screeningData in a variable for later use in _submitExamination
        setState(() {
          _examData['screening'] = screeningData;
        });
      },
    );
  }

  Widget _buildClinicalExaminationTab() {
 return SingleChildScrollView(
 padding: const EdgeInsets.all(16.0),
 child: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (widget.patientData != null) _buildPatientInfo(),
 _buildSection('Extraoral Examination', [
 _buildRadioGroup(
 title: 'TMJ',
 options: ['Normal', 'Deviation of mandible', 'Tenderness on palpation', 'Clicking sounds'],
 key: 'tmj',
 ),
 _buildRadioGroup(
 title: 'Lymph node of head and neck',
 options: ['Normal', 'Tender', 'Enlarged'],
 key: 'lymphNode',
 ),
 _buildRadioGroup(
 title: 'Patient profile',
 options: ['Straight', 'Convex', 'Concave'],
 key: 'patientProfile',
 ),
 _buildRadioGroup(
 title: 'Lip Competency',
 options: ['Competent', 'Incompetent', 'Potentially competent'],
 key: 'lipCompetency',
 ),
 ]),
 _buildSection('Intraoral Examination', [
 _buildRadioGroup(
 title: 'Incisal classification',
 options: ['Class I', 'Class II Div 1', 'Class II Div 2', 'Class III'],
 key: 'incisalClassification',
 ),
 _buildRadioGroup(
 title: 'Overjet',
 options: ['Normal', 'Increased', 'Decreased'],
 key: 'overjet',
 ),
 _buildRadioGroup(
 title: 'Overbite',
 options: ['Normal', 'Increased', 'Decreased'],
 key: 'overbite',
 ),
 ]),
 _buildSection('Soft Tissue Examination', [
 _buildRadioGroup(
 title: 'Hard Palate',
 options: ['Normal', 'Tori', 'Stomatitis', 'Ulcers', 'Red lesions'],
 key: 'hardPalate',
 ),
 _buildRadioGroup(
 title: 'Buccal mucosa',
 options: ['Normal', 'Pigmentation', 'Ulceration', 'Linea alba'],
 key: 'buccalMucosa',
 ),
 _buildRadioGroup(
 title: 'Floor of mouth',
 options: ['Normal', 'High frenum', 'Wharton\'s duct stenosis'],
 key: 'floorOfMouth',
 ),
 _buildRadioGroup(
 title: 'In full edentulous Arch the ridge is',
 options: ['Flappy', 'Severely resorbed', 'Well-developed ridge'],
 key: 'edentulousRidge',
 ),
 ]),
 _buildSection('Periodontal Chart (BPE)', [
 _buildPeriodontalChart(),
 ]),
 _buildSection('Dental Chart', [
 _buildDentalChart(),
 ]),
 ],
 ),
      ),
    );
  }

  Widget _buildXRayImageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (widget.patientData != null) _buildPatientInfo(),
          _buildSection('X-RAY Images', [
            Container(
              height: 300,
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: const Text('Panoramic X-RAY Image', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            Container(
              height: 300,
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: const Text('Cephalometric X-RAY Image', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add functionality to upload X-RAY images
              },
              child: const Text('Upload X-RAY Images'),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Examination'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Screening Form'),
            Tab(text: 'Clinical Examination'),
            Tab(text: 'X-RAY Image'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitExamination,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScreeningFormTab(),
          _buildClinicalExaminationTab(),
          _buildXRayImageTab(),
        ],
      ),
    );
  }
}

class TeethSelector extends StatefulWidget {
  final int? age;
  final bool multiSelect;
  final Color selectedColor;
  final Color unselectedColor;
  final Color tooltipColor;
  final List<String> initiallySelected;
  final Map<String, Color> colorized;
  final Map<String, Color> strokedColorized;
  final Color defaultStrokeColor;
  final Map<String, double> strokeWidth;
  final double defaultStrokeWidth;
  final String leftString;
  final String rightString;
  final bool showPermanent;
  final void Function(List<String> selected) onChange;
  final void Function(Map<String, Color> colors) onColorUpdate;
  final String Function(String isoString)? notation;
  final TextStyle? textStyle;
  final TextStyle? tooltipTextStyle;

  const TeethSelector({
    super.key,
    this.age,
    this.multiSelect = true,
    this.selectedColor = Colors.blue,
    this.unselectedColor = Colors.grey,
    this.tooltipColor = Colors.black,
    this.initiallySelected = const [],
    this.colorized = const {},
    this.strokedColorized = const {},
    this.defaultStrokeColor = Colors.transparent,
    this.strokeWidth = const {},
    this.defaultStrokeWidth = 1,
    this.notation,
    this.showPermanent = true,
    this.leftString = "Left",
    this.rightString = "Right",
    this.textStyle,
    this.tooltipTextStyle,
    required this.onChange,
    required this.onColorUpdate,
  });

  @override
  State<TeethSelector> createState() => _TeethSelectorState();
}

class _TeethSelectorState extends State<TeethSelector> {
  late Data data;
  Map<String, Color> localColorized = {};
  Map<String, bool> toothSelection = {};

  @override
  void initState() {
    super.initState();
    data = _loadTeethWithRetry();
    _initializeSelections();
  }

  Data _loadTeethWithRetry() {
    try {
      final loadedData = loadTeeth();
      return loadedData;
    } catch (e) {
      return (size: Size.zero, teeth: {});
    }
  }

  void _initializeSelections() {
    toothSelection = {
      for (var key in data.teeth.keys) key: false
    };

    for (var element in widget.initiallySelected) {
      if (data.teeth.containsKey(element)) {
        toothSelection[element] = true;
      }
    }

    localColorized = Map<String, Color>.from(widget.colorized);
  }

  int _parseToothNumber(String key) => int.tryParse(key) ?? 0;

  bool _isPrimaryTooth(String key) {
    final num = _parseToothNumber(key);
    return (num >= 51 && num <= 55) ||
        (num >= 61 && num <= 65) ||
        (num >= 71 && num <= 75) ||
        (num >= 81 && num <= 85);
  }

  bool _isPermanentTooth(String key) {
    final num = _parseToothNumber(key);
    return (num >= 11 && num <= 18) ||
        (num >= 21 && num <= 28) ||
        (num >= 31 && num <= 38) ||
        (num >= 41 && num <= 48);
  }

  @override
  Widget build(BuildContext context) {
    if (data.size == Size.zero) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool showPrimary = widget.age != null && widget.age! < 12;
    final visibleTeeth = data.teeth.entries.where((e) =>
    (showPrimary && _isPrimaryTooth(e.key)) ||
        (widget.showPermanent && _isPermanentTooth(e.key))
    ).toList();

    return FittedBox(
      child: SizedBox.fromSize(
        size: Size(data.size.width * 1.5, data.size.height * 1.5),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: data.size.height * 0.75 - 16,
              child: Text(
                widget.rightString,
                style: widget.textStyle ?? const TextStyle(fontSize: 16),
              ),
            ),
            Positioned(
              right: 20,
              top: data.size.height * 0.75 - 16,
              child: Text(
                widget.leftString,
                style: widget.textStyle ?? const TextStyle(fontSize: 16),
              ),
            ),

            for (final entry in visibleTeeth)
              _ToothWidget(
                key: ValueKey('tooth-${entry.key}-${toothSelection[entry.key]}'),
                toothKey: entry.key,
                tooth: entry.value,
                isSelected: toothSelection[entry.key] ?? false,
                selectedColor: widget.selectedColor,
                unselectedColor: widget.unselectedColor,
                tooltipColor: widget.tooltipColor,
                tooltipTextStyle: widget.tooltipTextStyle,
                notation: widget.notation,
                customColor: localColorized[entry.key],
                strokeColor: widget.strokedColorized[entry.key] ??
                    widget.defaultStrokeColor,
                strokeWidth: widget.strokeWidth[entry.key] ??
                    widget.defaultStrokeWidth,
                onTap: _handleToothTap,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleToothTap(String key) async {
    final diseaseColors = {
      'سليم': Colors.white,
      'تسوس': const Color(0xFF8B4513),
      'التهاب': Colors.red,
      'كسر': Colors.blueGrey,
      'حشوة': const Color(0xFFFFD700),
      'حشوة مؤقتة': const Color(0xFFFFFF00),
      'سن مفقود': Colors.black,
      'جسر': const Color(0xFFA020F0),
      'زرع': const Color(0xFF00FF00),
      'تلبيسة': const Color(0xFFFFA500),
    };

    final selectedDisease = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر الحالة للسن $key'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: diseaseColors.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: entry.value,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                onTap: () => Navigator.of(context).pop(entry.key),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (selectedDisease != null) {
      setState(() {
        if (!widget.multiSelect) {
          // Remove unnecessary null check here
          for (var k in toothSelection.keys) {
            toothSelection[k] = false;
          }
        }

        toothSelection[key] = true;
        localColorized[key] = diseaseColors[selectedDisease]!;

        widget.onChange(
            toothSelection.entries
                .where((e) => e.value)
                .map((e) => e.key)
                .toList()
        );

        widget.onColorUpdate(localColorized);
      });
    }
  }
}

class _ToothWidget extends StatelessWidget {
  final String toothKey;
  final Tooth tooth;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final Color tooltipColor;
  final TextStyle? tooltipTextStyle;
  final String Function(String)? notation;
  final Color? customColor;
  final Color strokeColor;
  final double strokeWidth;
  final Function(String) onTap;

  const _ToothWidget({
    required super.key,
    required this.toothKey,
    required this.tooth,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.tooltipColor,
    this.tooltipTextStyle,
    this.notation,
    this.customColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: Rect.fromLTWH(
        tooth.rect.left * 1.5,
        tooth.rect.top * 1.5,
        tooth.rect.width * 1.5,
        tooth.rect.height * 1.5,
      ),
      child: GestureDetector(
        onTap: () => onTap(toothKey),
        child: Tooltip(
          message: notation == null ? toothKey : notation!(toothKey),
          textStyle: tooltipTextStyle,
          decoration: BoxDecoration(
            color: tooltipColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: ShapeDecoration(
              color: customColor ?? (isSelected ? selectedColor : unselectedColor),
              shape: ToothBorder(
                tooth.path,
                strokeColor: strokeColor,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Tooth {
  late final Path path;
  late final Rect rect;

  Tooth(Path originalPath) {
    rect = originalPath.getBounds();
    path = originalPath.shift(-rect.topLeft);
  }
}

class ToothBorder extends ShapeBorder {
  final Path path;
  final double strokeWidth;
  final Color strokeColor;

  const ToothBorder(
      this.path, {
        required this.strokeWidth,
        required this.strokeColor,
      });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return rect.topLeft == Offset.zero ? path : path.shift(rect.topLeft);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor;
    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}

typedef Data = ({Size size, Map<String, Tooth> teeth});

Data loadTeeth() {
  try {
    final doc = XmlDocument.parse(svgString);
    final viewBox = doc.rootElement.getAttribute('viewBox')?.split(' ') ?? ['0','0','0','0'];
    final size = Size(
      double.parse(viewBox[2]),
      double.parse(viewBox[3]),
    );

    final teeth = <String, Tooth>{};
    for (final element in doc.rootElement.findAllElements('path')) {
      final id = element.getAttribute('id');
      final pathData = element.getAttribute('d');
      if (id != null && pathData != null) {
        try {
          teeth[id] = Tooth(parseSvgPathData(pathData));
        } catch (e) {
          debugPrint('Error parsing tooth $id: $e');
        }
      }
    }
    return (size: size, teeth: teeth);
  } catch (e) {
    debugPrint('Error loading SVG: $e');
    return (size: Size.zero, teeth: {});
  }
}