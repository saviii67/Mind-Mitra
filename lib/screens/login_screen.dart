import 'package:flutter/material.dart';
import '../models/patient_profile.dart';
import '../services/storage_service.dart';
import '../services/localization_service.dart';
import '../services/voice_service.dart';
import '../services/india_locations.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final bool isEditing;

  const LoginScreen({super.key, this.isEditing = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _caregiverNameController;
  late TextEditingController _caregiverPhoneController;
  late TextEditingController _doctorNameController;

  String _selectedGender = 'Female';
  String _selectedLanguage = 'en';
  String? _selectedState;
  String? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    final current = StorageService.profileNotifier.value;
    _nameController = TextEditingController(text: widget.isEditing ? current.name : '');
    _ageController = TextEditingController(text: widget.isEditing ? current.age.toString() : '');
    _caregiverNameController = TextEditingController(text: widget.isEditing ? current.caregiverName : '');
    _caregiverPhoneController = TextEditingController(text: widget.isEditing ? current.caregiverPhone : '');
    _doctorNameController = TextEditingController(text: widget.isEditing ? current.doctorName : '');
    _selectedGender = widget.isEditing ? current.gender : 'Female';
    _selectedLanguage = widget.isEditing ? current.selectedLanguage : 'en';

    if (widget.isEditing && current.city.contains(',')) {
      final parts = current.city.split(',');
      final parsedDistrict = parts.first.trim();
      final parsedState = parts.sublist(1).join(',').trim();
      if (IndiaLocations.states.contains(parsedState)) {
        _selectedState = parsedState;
        final districts = IndiaLocations.districtsForState(parsedState);
        if (districts.contains(parsedDistrict)) {
          _selectedDistrict = parsedDistrict;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _caregiverNameController.dispose();
    _caregiverPhoneController.dispose();
    _doctorNameController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final current = StorageService.profileNotifier.value;
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 70;
    final city = '${_selectedDistrict ?? ''}, ${_selectedState ?? ''}';
    final caregiverName = _caregiverNameController.text.trim().isEmpty
        ? 'Family Caregiver'
        : _caregiverNameController.text.trim();
    final caregiverPhone = _caregiverPhoneController.text.trim().isEmpty
        ? '14567'
        : _caregiverPhoneController.text.trim();
    final doctorName = _doctorNameController.text.trim().isEmpty
        ? 'Family Physician'
        : _doctorNameController.text.trim();

    final updatedProfile = PatientProfile(
      id: widget.isEditing ? current.id : 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      age: age,
      gender: _selectedGender,
      city: city,
      caregiverName: caregiverName,
      caregiverRelationship: 'Family Caregiver',
      caregiverPhone: caregiverPhone,
      doctorName: doctorName,
      doctorPhone: '14567',
      selectedLanguage: _selectedLanguage,
    );

    if (widget.isEditing) {
      await StorageService.savePatientProfile(updatedProfile);
      LocalizationService.setLanguage(updatedProfile.selectedLanguage);
    } else {
      await StorageService.loginWithProfile(updatedProfile);
      VoiceService.speak('Welcome to MindMitra, $name from $city!');
    }

    if (widget.isEditing && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableDistricts = IndiaLocations.districtsForState(_selectedState);

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: widget.isEditing
          ? AppBar(
              title: const Text('Edit Profile Details'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Logo & Title
                        const Text(
                          '🌿 MindMitra',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F4F44),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isEditing
                              ? 'Update your personal and caregiver information'
                              : 'Welcome! Please enter your details to personalize your companion experience.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 24),

                        // Section 1: Personal Details
                        const Text(
                          '👤 Personal Information',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                        ),
                        const SizedBox(height: 14),

                        // Full Name
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(fontSize: 18),
                          decoration: _inputDecoration(
                            label: 'Full Name *',
                            hint: 'Enter full name',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                        ),
                        const SizedBox(height: 16),

                        // Age & Gender Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Age
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 18),
                                decoration: _inputDecoration(
                                  label: 'Age *',
                                  hint: 'Enter age',
                                  icon: Icons.cake_outlined,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter age';
                                  final n = int.tryParse(val.trim());
                                  if (n == null || n < 1 || n > 120) return 'Valid age';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Preferred Language
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _selectedLanguage,
                                isExpanded: true,
                                decoration: _inputDecoration(
                                  label: 'Language',
                                  hint: '',
                                  icon: Icons.language_rounded,
                                ),
                                items: LocalizationService.supportedLanguages.entries
                                    .map(
                                      (e) => DropdownMenuItem<String>(
                                        value: e.key,
                                        child: Text(e.value, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedLanguage = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Gender Selector Pills
                        const Text(
                          'Gender *',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _GenderButton(
                                label: '👩 Female',
                                selected: _selectedGender == 'Female',
                                onTap: () => setState(() => _selectedGender = 'Female'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _GenderButton(
                                label: '👨 Male',
                                selected: _selectedGender == 'Male',
                                onTap: () => setState(() => _selectedGender = 'Male'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _GenderButton(
                                label: '🧑 Other',
                                selected: _selectedGender == 'Other',
                                onTap: () => setState(() => _selectedGender = 'Other'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 1. State of India Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedState,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            label: 'State / Union Territory *',
                            hint: 'Select State',
                            icon: Icons.map_outlined,
                          ),
                          hint: const Text('Select State'),
                          items: IndiaLocations.states
                              .map(
                                (state) => DropdownMenuItem<String>(
                                  value: state,
                                  child: Text(state, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (newState) {
                            setState(() {
                              _selectedState = newState;
                              _selectedDistrict = null;
                            });
                          },
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Please select your state' : null,
                        ),
                        const SizedBox(height: 16),

                        // 2. District of Selected State Dropdown
                        DropdownButtonFormField<String>(
                          key: ValueKey<String?>(_selectedState),
                          value: _selectedDistrict,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            label: 'District *',
                            hint: _selectedState == null ? 'Select a state first' : 'Select District',
                            icon: Icons.location_city_rounded,
                          ),
                          hint: Text(
                            _selectedState == null ? 'Select a state first' : 'Select District',
                          ),
                          items: availableDistricts
                              .map(
                                (district) => DropdownMenuItem<String>(
                                  value: district,
                                  child: Text(district, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: _selectedState == null
                              ? null
                              : (newDistrict) {
                                  setState(() {
                                    _selectedDistrict = newDistrict;
                                  });
                                },
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Please select your district' : null,
                        ),
                        const SizedBox(height: 24),

                        // Section 2: Caregiver & Emergency Details
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text(
                          '🤝 Caregiver & Support Details',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _caregiverNameController,
                          style: const TextStyle(fontSize: 17),
                          decoration: _inputDecoration(
                            label: 'Caregiver / Family Member Name',
                            hint: 'Enter caregiver name',
                            icon: Icons.favorite_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _caregiverPhoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 17),
                          decoration: _inputDecoration(
                            label: 'Caregiver Phone Number',
                            hint: 'Enter phone number',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7C6F),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 58),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _submitLogin,
                          child: Text(
                            widget.isEditing ? '✅ Save Profile Changes' : '🌿 Login & Open MindMitra',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF4A7C6F)),
      filled: true,
      fillColor: const Color(0xFFF9FBF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCFDCD7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCFDCD7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4A7C6F), width: 2),
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4A7C6F) : const Color(0xFFF4F7F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF4A7C6F) : const Color(0xFFCFDCD7),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : const Color(0xFF2F4F44),
          ),
        ),
      ),
    );
  }
}
