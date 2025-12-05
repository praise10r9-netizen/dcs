import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthController {
  final SupabaseService _service = SupabaseService();
  
  Future<String?> register({
    required String email,
    required String password,
    required String firstname,
    required String lastname,
    required String role,
    required String qualification,
  }) async {
    return _service.registerUser(
      email: email,
      password: password,
      firstname: firstname,
      lastname: lastname,
      role: role,
      qualification: qualification,
    );
  }
  
  Future<String?> login(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    final error = await _service.loginUser(email: email, password: password);
    if (error != null) return error;
    
    if (!context.mounted) return null;
    await _redirectUser(context);
    return null;
  }
  
  Future<void> checkSession(BuildContext context) async {
    final user = _service.supabase.auth.currentUser;
    if (user != null) {
      await _redirectUser(context);
    } else {
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
  
  // FIXED: This method now returns User? instead of String?
  User? getCurrentUser(BuildContext context) {
    return _service.supabase.auth.currentUser;
  }
  
  // Alternative: Check if user is logged in (returns boolean)
  bool isLoggedIn() {
    return _service.supabase.auth.currentUser != null;
  }
  
  Future<void> _redirectUser(BuildContext context) async {
    if (!context.mounted) return;
    
    final role = await _service.getUserRole();
    
    if (!context.mounted) return;
    
    if (role == 'field_worker') {
      Navigator.pushReplacementNamed(context, '/fieldWorker');
    } else if (role == 'supervisor') {
      Navigator.pushReplacementNamed(context, '/supervisor');
    } else if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin');
    } else {
      Navigator.pushReplacementNamed(context, '/unknownRole');
    }
  }
  
  Future<void> logout(BuildContext context) async {
    await _service.supabase.auth.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }
}