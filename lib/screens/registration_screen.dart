import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _auth = AuthController();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();

  String _role = 'field_worker'; // Default role

  bool _loading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _performRegistration() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final res = await _auth.register(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      firstname: _firstNameCtrl.text.trim(),
      lastname: _lastNameCtrl.text.trim(),
      role: _role,
      qualification: _qualificationCtrl.text.trim(),
    );

    if (res != null) {
      setState(() => _errorMessage = res);
    } else {
      setState(() => _successMessage = "Registration successful! You can now log in.");
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Register",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // FIRST NAME
              TextField(
                controller: _firstNameCtrl,
                decoration: InputDecoration(
                  labelText: "First Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // LAST NAME
              TextField(
                controller: _lastNameCtrl,
                decoration: InputDecoration(
                  labelText: "Last Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // EMAIL
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // PASSWORD
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // QUALIFICATION
              TextField(
                controller: _qualificationCtrl,
                decoration: InputDecoration(
                  labelText: "Qualification",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ROLE DROPDOWN
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: InputDecoration(
                  labelText: "Select Role",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "field_worker",
                    child: Text("Field Worker"),
                  ),
                  DropdownMenuItem(
                    value: "supervisor",
                    child: Text("Supervisor"),
                  ),
                  DropdownMenuItem(
                    value: "admin",
                    child: Text("Administrator"),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),

              const SizedBox(height: 20),

              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              if (_successMessage != null)
                Text(
                  _successMessage!,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : _performRegistration,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Register",
                        style: TextStyle(fontSize: 18),
                      ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
