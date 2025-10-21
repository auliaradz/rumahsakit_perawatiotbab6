import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Monitoring Pasien',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PatientMonitoringScreen(),
    );
  }
}

class PatientMonitoringScreen extends StatefulWidget {
  const PatientMonitoringScreen({super.key});

  @override
  State<PatientMonitoringScreen> createState() => _PatientMonitoringScreenState();
}

class _PatientMonitoringScreenState extends State<PatientMonitoringScreen> {
  DatabaseReference? _databaseRef;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Hardcoded credentials for automatic authentication
  final String _email = 'auliaaaaa@firebase.com';
  final String _password = '123456';
  
  List<Patient> _patients = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // Sign in automatically with hardcoded credentials first
      await _signIn();
      
      // Initialize database reference after Firebase is ready
      // Create a database instance that uses the correct URL
      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://rumahsakitbab6-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
      _databaseRef = database.ref('rumahsakit-db');
      
      debugPrint('Database reference created and pointing to rumahsakit-db');
      
      // Listen to real-time database updates
      _listenToPatientUpdates();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing app: $e';
        _isLoading = false;
      });
      debugPrint('Error in _initApp: $e');
    }
  }

  Future<void> _signIn() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      );
    } catch (e) {
      // If login fails, create the user first (for demo purposes)
      try {
        await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
      } catch (createError) {
        throw Exception('Failed to authenticate: $createError');
      }
    }
  }

  void _listenToPatientUpdates() {
    _databaseRef!.onValue.listen((event) {
      debugPrint('Database updated: ${event.snapshot.value}');
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final patients = <Patient>[];
        data.forEach((key, value) {
          if (value is Map) {
            // Handle different possible map types
            int status = 0;
            String message = '';
            
            if (value.containsKey('status')) {
              var statusValue = value['status'];
              if (statusValue is int) {
                status = statusValue;
              } else if (statusValue is String) {
                status = int.tryParse(statusValue) ?? 0;
              } else if (statusValue is double) {
                status = statusValue.toInt();
              }
            }
            
            if (value.containsKey('message')) {
              var messageValue = value['message'];
              message = messageValue?.toString() ?? '';
            }
            
            final patient = Patient(
              id: key,
              status: status,
              message: message,
            );
            
            debugPrint('Processing patient $key with status $status and message "$message"');
            
            // Only add patients with status = 1 (need help)
            if (status == 1) {
              patients.add(patient);
            }
          }
        });
        
        setState(() {
          _patients = patients;
          _isLoading = false;
          _errorMessage = '';
        });
        debugPrint('Updated patients list: ${patients.length} patients need help');
      } else {
        setState(() {
          _patients = [];
          _isLoading = false;
        });
        debugPrint('Database is empty or null');
      }
    }, onError: (error) {
      setState(() {
        _errorMessage = 'Error fetching data: $error';
        _isLoading = false;
      });
      debugPrint('Database error: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aplikasi Monitoring Pasien')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initApp,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplikasi Monitoring Pasien'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _patients.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sentiment_very_satisfied,
                        size: 64,
                        color: Colors.green,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tidak ada pasien yang membutuhkan bantuan saat ini',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    // Trigger data refresh
                    await _initApp();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _patients.length,
                    itemBuilder: (context, index) {
                      return PatientCard(patient: _patients[index]);
                    },
                  ),
                ),
    );
  }
}

class Patient {
  final String id;
  final int status;
  final String message;

  Patient({
    required this.id,
    required this.status,
    required this.message,
  });
}

class PatientCard extends StatelessWidget {
  final Patient patient;

  const PatientCard({
    super.key,
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'BUTUH BANTUAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ID Pasien: ${patient.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pesan: ${patient.message}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}