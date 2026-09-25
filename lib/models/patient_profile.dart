import 'dart:convert';

/// Represents the logged-in user/patient profile and linked caregiver details.
class PatientProfile {
  final String id;
  final String name;
  final int age;
  final String gender; // 'Male', 'Female', 'Other'
  final String city; // e.g. 'Guwahati, Assam'
  final String caregiverName;
  final String caregiverRelationship;
  final String caregiverPhone;
  final String doctorName;
  final String doctorPhone;
  final String emergencyHelpline;
  final String selectedLanguage; // 'en', 'hi', 'as', 'bn'
  final String stageNotes;

  PatientProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.city,
    required this.caregiverName,
    required this.caregiverRelationship,
    required this.caregiverPhone,
    required this.doctorName,
    required this.doctorPhone,
    this.emergencyHelpline = '14567',
    this.selectedLanguage = 'en',
    this.stageNotes = 'Daily Cognitive Wellness & Memory Support',
  });

  /// Alias for region compatibility
  String get region => city;

  factory PatientProfile.defaultProfile() {
    return PatientProfile(
      id: 'user_default',
      name: 'User',
      age: 65,
      gender: 'Female',
      city: 'India',
      caregiverName: 'Family Caregiver',
      caregiverRelationship: 'Family Caregiver',
      caregiverPhone: '14567',
      doctorName: 'Family Physician',
      doctorPhone: '14567',
      emergencyHelpline: '14567',
      selectedLanguage: 'en',
      stageNotes: 'Daily Cognitive Wellness & Memory Support',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'city': city,
      'caregiverName': caregiverName,
      'caregiverRelationship': caregiverRelationship,
      'caregiverPhone': caregiverPhone,
      'doctorName': doctorName,
      'doctorPhone': doctorPhone,
      'emergencyHelpline': emergencyHelpline,
      'selectedLanguage': selectedLanguage,
      'stageNotes': stageNotes,
    };
  }

  factory PatientProfile.fromMap(Map<String, dynamic> map) {
    return PatientProfile(
      id: map['id'] ?? 'user_default',
      name: map['name'] ?? 'User',
      age: map['age'] is int ? map['age'] : int.tryParse(map['age']?.toString() ?? '65') ?? 65,
      gender: map['gender'] ?? 'Female',
      city: map['city'] ?? map['region'] ?? 'India',
      caregiverName: map['caregiverName'] ?? 'Family Caregiver',
      caregiverRelationship: map['caregiverRelationship'] ?? 'Family Caregiver',
      caregiverPhone: map['caregiverPhone'] ?? '14567',
      doctorName: map['doctorName'] ?? 'Family Physician',
      doctorPhone: map['doctorPhone'] ?? '14567',
      emergencyHelpline: map['emergencyHelpline'] ?? '14567',
      selectedLanguage: map['selectedLanguage'] ?? 'en',
      stageNotes: map['stageNotes'] ?? 'Daily Cognitive Wellness & Memory Support',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PatientProfile.fromJson(String source) =>
      PatientProfile.fromMap(jsonDecode(source));

  PatientProfile copyWith({
    String? name,
    int? age,
    String? gender,
    String? city,
    String? caregiverName,
    String? caregiverRelationship,
    String? caregiverPhone,
    String? doctorName,
    String? doctorPhone,
    String? selectedLanguage,
    String? stageNotes,
  }) {
    return PatientProfile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      caregiverName: caregiverName ?? this.caregiverName,
      caregiverRelationship: caregiverRelationship ?? this.caregiverRelationship,
      caregiverPhone: caregiverPhone ?? this.caregiverPhone,
      doctorName: doctorName ?? this.doctorName,
      doctorPhone: doctorPhone ?? this.doctorPhone,
      emergencyHelpline: emergencyHelpline,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      stageNotes: stageNotes ?? this.stageNotes,
    );
  }
}
