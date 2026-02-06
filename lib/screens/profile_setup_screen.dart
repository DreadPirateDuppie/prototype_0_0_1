import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/cyber/cyber_scaffold.dart';
import '../widgets/cyber/cyber_button.dart';
import '../widgets/cyber/cyber_text_field.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  final _ageController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUserProfile(); // Refresh data
    
    if (mounted) {
      if (userProvider.username != null) {
        _usernameController.text = userProvider.username!;
      }
      if (userProvider.age != null) {
        _ageController.text = userProvider.age.toString();
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _errorMessage = null);

    final username = _usernameController.text.trim();
    final ageText = _ageController.text.trim();

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Username required');
      return;
    }

    if (ageText.isEmpty) {
      setState(() => _errorMessage = 'Age required');
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null || age < 13) {
      setState(() => _errorMessage = 'Minimum age requirement: 13+');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Update Username
      if (username != userProvider.username) {
        final success = await userProvider.updateUsername(username);
        if (!success) throw Exception('Username taken or invalid');
      }

      // Update Age
      if (age != userProvider.age) {
        await userProvider.updateAge(age);
      }

      // Upload Avatar if changed
      if (_imageFile != null) {
        final userId = userProvider.currentUser?.id;
        if (userId != null) {
           final imageUrl = await SupabaseService.uploadProfileImage(userId, _imageFile!);
           userProvider.updateAvatarUrl(imageUrl);
        }
      }

      if (mounted) {
        // Navigate to Home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final avatarUrl = userProvider.avatarUrl;

    return CyberScaffold(
      showGrid: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "IDENTITY CONFIGURATION",
                style: TextStyle(
                  color: Color(0xFF00FF41),
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),

              // Avatar Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00FF41), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF41).withOpacity(0.2), // Fixed withOpacity
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : (avatarUrl != null
                            ? Image.network(avatarUrl, fit: BoxFit.cover)
                            : const Icon(Icons.add_a_photo, color: Color(0xFF00FF41), size: 40)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "UPLOAD AVATAR",
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              
              const SizedBox(height: 48),

              CyberTextField(
                controller: _usernameController,
                label: 'Operative Handle', // Username
                prefixIcon: Icons.alternate_email,
              ),
              
              const SizedBox(height: 20),

              CyberTextField(
                controller: _ageController,
                label: 'Years Operational', // Age
                prefixIcon: Icons.calendar_today,
                keyboardType: TextInputType.number,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Text(
                  _errorMessage!.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFF4444),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],

              const SizedBox(height: 48),

              CyberButton(
                text: "CONFIRM IDENTITY",
                onPressed: _saveProfile,
                isLoading: _isLoading,
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
