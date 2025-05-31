import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class SearchPatientSecurityPage extends StatefulWidget {
  const SearchPatientSecurityPage({super.key});

  @override
  State<SearchPatientSecurityPage> createState() =>
      _SearchPatientSecurityPageState();
}

class _SearchPatientSecurityPageState extends State<SearchPatientSecurityPage> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  final String _searchType = 'name'; // البحث دائماً بالاسم

  void _onSearchChanged() {
    _searchPatients();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _results = [];
    });
    try {
      final snapshot = await _database.child('users').once();
      List<Map<String, dynamic>> found = [];
      if (snapshot.snapshot.value != null) {
        final rawData = snapshot.snapshot.value;
        Map<String, dynamic> data;
        if (rawData is Map) {
          data = Map<String, dynamic>.from(rawData);
        } else if (rawData is List) {
          data = {};
          for (int i = 0; i < rawData.length; i++) {
            if (rawData[i] != null) {
              data[i.toString()] = rawData[i];
            }
          }
        } else {
          data = {};
        }
        data.forEach((key, value) {
          final user = Map<String, dynamic>.from(value);
          final fullName = (user['firstName'] ?? '') +
              ' ' +
              (user['fatherName'] ?? '') +
              ' ' +
              (user['grandfatherName'] ?? '') +
              ' ' +
              (user['familyName'] ?? '');
          final fullNameLower = fullName.trim().toLowerCase();
          final idNumber = user['idNumber']?.toString() ?? '';
          if (fullNameLower.contains(query.toLowerCase()) ||
              idNumber.contains(query)) {
            found.add({...user, 'fullName': fullName.trim(), 'uid': key});
          }
        });
      }
      // Check appointments for today
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      for (var user in found) {
        final uid = user['uid'];
        final appointmentsSnap = await _database
            .child('appointments')
            .orderByChild('patientId')
            .equalTo(uid)
            .once();
        bool hasAppointmentToday = false;
        if (appointmentsSnap.snapshot.value != null) {
          final appointments =
              Map<String, dynamic>.from(appointmentsSnap.snapshot.value as Map);
          for (var appt in appointments.values) {
            final apptData = Map<String, dynamic>.from(appt);
            if (apptData['date'] == today) {
              hasAppointmentToday = true;
              break;
            }
          }
        }
        user['hasAppointmentToday'] = hasAppointmentToday;
      }
      setState(() {
        _results = found;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء البحث: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث عن المرضى'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'ابحث بالاسم أو رقم الهوية',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading) const CircularProgressIndicator(),
            if (!_isLoading &&
                _results.isEmpty &&
                _searchController.text.isNotEmpty)
              const Text('لا يوجد نتائج'),
            if (!_isLoading && _results.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return Card(
                      child: ListTile(
                        title: Text(user['fullName'] ?? ''),
                        subtitle: Text('رقم الهوية: ${user['idNumber'] ?? ''}'),
                        trailing: user['hasAppointmentToday'] == true
                            ? const Chip(
                                label: Text('لديه موعد اليوم',
                                    style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.green)
                            : const Chip(
                                label: Text('لا يوجد موعد اليوم',
                                    style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.red),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
