import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _organizationNameController = TextEditingController();
  final _organizationAddressController = TextEditingController();
  final _organizationTypeController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _organizationDescriptionController = TextEditingController();
  
  // Security Questions Controllers

  
  
  String? _selectedRole;
  String? _selectedOrganizationType;

  bool _isLoading = false;
  bool _emailVerified = false;
  
  final List<String> _roles = ['Donor', 'Organization', 'Administrator'];
  final List<String> _organizationTypes = [
    'NGO/Non-Profit',
    'Hospital/Medical',
    'School/Education',
    'Religious Organization',
    'Community Center',
    'Other'
  ];



  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    setState(() {
      _emailVerified = RegExp(r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$').hasMatch(email);
    });
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate() || _selectedRole == null) return;

    if (!_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }



    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Determine initial status
      final status = _selectedRole == 'Organization' ? 'pending' : 'approved';

      // Prepare user data
      final userData = {
        'email': email,
        'role': _selectedRole,
        'status': status,
        'name': name,
        'username': _usernameController.text.trim(),
        'emailVerified': _emailVerified,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      // Add organization-specific fields
      if (_selectedRole == 'Organization') {
        userData['organizationName'] = _organizationNameController.text.trim();
        userData['organizationAddress'] = _organizationAddressController.text.trim();
        userData['organizationType'] = _selectedOrganizationType;
        userData['registrationNumber'] = _registrationNumberController.text.trim();
        userData['organizationDescription'] = _organizationDescriptionController.text.trim();
        userData['organizationVerified'] = false;
        // Location will be set when organization makes their first donation request
      }

      // Save user data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      // Email verification removed

      // Create admin notification for organization approval
      if (_selectedRole == 'Organization') {
        await FirebaseFirestore.instance.collection('admin_notifications').add({
          'type': 'organization_approval',
          'title': 'New Organization Registration',
          'message': 'Organization ${_organizationNameController.text.trim()} (${email}) has registered and is pending approval.',
          'organizationId': userCredential.user!.uid,
          'organizationName': _organizationNameController.text.trim(),
          'organizationEmail': email,
          'organizationAddress': _organizationAddressController.text.trim(),
          'organizationType': _selectedOrganizationType,
          'registrationNumber': _registrationNumberController.text.trim(),
          'organizationDescription': _organizationDescriptionController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'starred': false,
        });
      }

      print('✅ Signup successful for $email with role $_selectedRole');

      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedRole == 'Organization' 
            ? 'Registration successful! Please wait for admin approval.'
            : 'Registration successful! Please check your email for verification.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Signup failed')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role Selection
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: _roles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedRole = value),
                decoration: const InputDecoration(
                  labelText: 'Select Role',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'Select a role' : null,
              ),
              const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 2) return 'Name must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Username Field
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  hintText: 'Choose a unique username',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 3) return 'Username must be at least 3 characters';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return 'Username can only contain letters, numbers, and underscores';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Field with Verification
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  suffixIcon: _emailVerified 
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (!_emailVerified) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Organization-specific fields
              if (_selectedRole == 'Organization') ...[
                TextFormField(
                  controller: _organizationNameController,
                  decoration: const InputDecoration(
                    labelText: 'Organization Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _organizationAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Organization Address',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedOrganizationType,
                  items: _organizationTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedOrganizationType = value),
                  decoration: const InputDecoration(
                    labelText: 'Organization Type',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null ? 'Select an organization type' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _registrationNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Registration Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _organizationDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Organization Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Security Questions

              const SizedBox(height: 16),

              // Password Fields
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Sign Up', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Already have an account? Log In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _organizationNameController.dispose();
    _organizationAddressController.dispose();
    _organizationTypeController.dispose();
    _registrationNumberController.dispose();
    _organizationDescriptionController.dispose();
    
    
    super.dispose();
  }
}

