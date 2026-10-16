import '../models/user_model.dart';
import '../models/family_model.dart';
import '../models/member_model.dart';
import '../models/doctor_model.dart';
import '../models/visit_model.dart';
import '../models/medication_model.dart';
import '../models/med_file_model.dart';

class AppointmentModel {
  final String id;
  final String memberId;
  final String memberName;
  final String? doctorId;
  final String doctorName;
  final String specialization;
  final DateTime dateTime;
  final String title;
  final String status;

  AppointmentModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.dateTime,
    required this.title,
    this.status = 'Upcoming',
  });
}

class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;

  MockDataService._internal() {
    _initMockData();
  }

  UserModel? currentUser;
  final List<FamilyModel> families = [];
  final List<MemberModel> members = [];
  final List<DoctorModel> doctors = [];
  final List<VisitModel> visits = [];
  final List<MedicationModel> medications = [];
  final List<MedFileModel> files = [];
  final List<AppointmentModel> appointments = [];
  final List<String> recentSearches = ['Ali Ahmed'];

  void _initMockData() {
    // Current User
    currentUser = UserModel(
      id: 'usr-100',
      email: 'ahmed@example.com',
      fullName: 'Ahmed Khan',
      phone: '+92 300 9876543',
      avatarUrl: null,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    );

    // Families
    families.addAll([
      FamilyModel(
        id: 'fam-1',
        familyId: 'FAM-1001',
        name: 'Ahmed Family',
        contact: '+92 300 1234567',
        address: 'Model Town, Lahore',
        userId: 'usr-100',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      FamilyModel(
        id: 'fam-2',
        familyId: 'FAM-1002',
        name: 'Khan Family',
        contact: '+92 321 7654321',
        address: 'F-7/2, Islamabad',
        userId: 'usr-100',
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
    ]);

    // Members
    members.addAll([
      MemberModel(
        id: 'mem-1',
        familyId: 'fam-1',
        name: 'Ahmed',
        relation: 'Father',
        dob: DateTime(1982, 5, 14),
        gender: 'Male',
        bloodGroup: 'O+',
        allergies: 'Dust, Pollen',
        notes: 'Head of family',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      MemberModel(
        id: 'mem-2',
        familyId: 'fam-1',
        name: 'Sara Ahmed',
        relation: 'Wife',
        dob: DateTime(1986, 9, 21),
        gender: 'Female',
        bloodGroup: 'B+',
        allergies: null,
        notes: 'Blood group B+',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      MemberModel(
        id: 'mem-3',
        familyId: 'fam-1',
        name: 'Ali Ahmed',
        relation: 'Son',
        dob: DateTime(2014, 4, 12),
        gender: 'Male',
        bloodGroup: 'O+',
        allergies: 'No known allergies recorded',
        notes: 'No chronic conditions recorded',
        createdAt: DateTime.now().subtract(const Duration(days: 85)),
      ),
      MemberModel(
        id: 'mem-4',
        familyId: 'fam-1',
        name: 'Ayan Ahmed',
        relation: 'Son',
        dob: DateTime(2020, 8, 15),
        gender: 'Male',
        bloodGroup: 'A+',
        allergies: null,
        notes: null,
        createdAt: DateTime.now().subtract(const Duration(days: 80)),
      ),
      MemberModel(
        id: 'mem-5',
        familyId: 'fam-2',
        name: 'Maryam Khan',
        relation: 'Daughter',
        dob: DateTime(2010, 2, 10),
        gender: 'Female',
        bloodGroup: 'A+',
        allergies: null,
        notes: null,
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
      MemberModel(
        id: 'mem-6',
        familyId: 'fam-2',
        name: 'Sami Khan',
        relation: 'Son',
        dob: DateTime(2007, 11, 30),
        gender: 'Male',
        bloodGroup: 'B+',
        allergies: null,
        notes: null,
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
    ]);

    // Doctors
    doctors.addAll([
      DoctorModel(
        id: 'doc-1',
        userId: 'usr-100',
        name: 'Dr. Sana Malik',
        specialization: 'Pediatrician',
        hospital: 'City Children\'s Clinic',
        phone: '+92 300 5551234',
        address: 'Model Town, Lahore',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      DoctorModel(
        id: 'doc-2',
        userId: 'usr-100',
        name: 'Dr. Bilal Khan',
        specialization: 'General Physician',
        hospital: 'National Hospital',
        phone: '+92 321 4445678',
        address: 'DHA Phase 5, Lahore',
        createdAt: DateTime.now().subtract(const Duration(days: 70)),
      ),
      DoctorModel(
        id: 'doc-3',
        userId: 'usr-100',
        name: 'Dr. Hamza Tariq',
        specialization: 'ENT Specialist',
        hospital: 'Tariq ENT Care',
        phone: '+92 333 9998877',
        address: 'Gulberg III, Lahore',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ]);

    // Visits
    visits.addAll([
      VisitModel(
        id: 'vis-1',
        memberId: 'mem-3',
        doctorId: 'doc-1',
        visitDate: DateTime(2026, 10, 12, 10, 30),
        symptoms: 'Fever, sore throat and mild cough',
        diagnosis: 'Seasonal viral infection',
        treatment: 'Rest, warm fluids, Paracetamol syrup',
        notes: 'Follow up if fever persists beyond 3 days',
        followUpDate: DateTime(2026, 10, 21, 11, 30),
        createdAt: DateTime(2026, 10, 12),
        memberName: 'Ali Ahmed',
        doctorName: 'Dr. Sana Malik',
      ),
      VisitModel(
        id: 'vis-2',
        memberId: 'mem-2',
        doctorId: 'doc-2',
        visitDate: DateTime(2026, 10, 5, 11, 0),
        symptoms: 'Routine annual health check-up',
        diagnosis: 'General check-up • All vitals normal',
        treatment: 'Maintain balanced diet and hydration',
        notes: 'Routine blood screening requested',
        followUpDate: DateTime(2026, 10, 25, 10, 0),
        createdAt: DateTime(2026, 10, 5),
        memberName: 'Sara Ahmed',
        doctorName: 'Dr. Bilal Khan',
      ),
      VisitModel(
        id: 'vis-3',
        memberId: 'mem-1',
        doctorId: 'doc-3',
        visitDate: DateTime(2026, 9, 18, 14, 0),
        symptoms: 'Sneezing, nasal congestion and eye irritation',
        diagnosis: 'Seasonal allergic rhinitis',
        treatment: 'Antihistamine daily for 7 days',
        notes: 'Avoid outdoor dust during weather change',
        followUpDate: DateTime(2026, 11, 2, 14, 0),
        createdAt: DateTime(2026, 9, 18),
        memberName: 'Ahmed',
        doctorName: 'Dr. Hamza Tariq',
      ),
    ]);

    // Medications
    medications.addAll([
      MedicationModel(
        id: 'med-1',
        visitId: 'vis-1',
        name: 'Paracetamol syrup',
        dosage: '5 ml',
        frequency: 'Twice daily',
        duration: '3 days',
        notes: 'After meals; follow doctor\'s advice.',
      ),
      MedicationModel(
        id: 'med-2',
        visitId: 'vis-3',
        name: 'Loratadine 10mg',
        dosage: '1 tablet',
        frequency: 'Once at night',
        duration: '7 days',
        notes: 'Take before sleep.',
      ),
    ]);

    // Files / Documents
    files.addAll([
      MedFileModel(
        id: 'file-1',
        visitId: 'vis-1',
        memberId: 'mem-3',
        fileUrl: 'assets/docs/Prescription_12Oct.pdf',
        fileType: 'prescription',
        description: 'Prescription_12Oct.pdf',
        createdAt: DateTime(2026, 10, 12),
      ),
      MedFileModel(
        id: 'file-2',
        visitId: 'vis-2',
        memberId: 'mem-2',
        fileUrl: 'assets/docs/CBC_Blood_Test.jpg',
        fileType: 'labReport',
        description: 'CBC Blood Test.jpg',
        createdAt: DateTime(2026, 10, 5),
      ),
      MedFileModel(
        id: 'file-3',
        visitId: 'vis-3',
        memberId: 'mem-1',
        fileUrl: 'assets/docs/Chest_XRay_Report.pdf',
        fileType: 'xray',
        description: 'Chest_XRay_Report.pdf',
        createdAt: DateTime(2026, 9, 21),
      ),
    ]);

    // Appointments
    appointments.addAll([
      AppointmentModel(
        id: 'app-1',
        memberId: 'mem-3',
        memberName: 'Ali Ahmed',
        doctorId: 'doc-1',
        doctorName: 'Dr. Sana Malik',
        specialization: 'Pediatrician',
        dateTime: DateTime(2026, 10, 21, 11, 30),
        title: 'Upcoming Follow-up',
      ),
      AppointmentModel(
        id: 'app-2',
        memberId: 'mem-2',
        memberName: 'Sara Ahmed',
        doctorId: 'doc-2',
        doctorName: 'Dr. Bilal Khan',
        specialization: 'General Physician',
        dateTime: DateTime(2026, 10, 25, 10, 0),
        title: 'General Check-up',
      ),
      AppointmentModel(
        id: 'app-3',
        memberId: 'mem-1',
        memberName: 'Ahmed',
        doctorId: 'doc-3',
        doctorName: 'Dr. Hamza Tariq',
        specialization: 'ENT Specialist',
        dateTime: DateTime(2026, 11, 2, 14, 0),
        title: 'Lab Follow-up',
      ),
    ]);
  }
}
