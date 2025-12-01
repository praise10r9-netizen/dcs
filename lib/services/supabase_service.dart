import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService 
{
  final supabase = Supabase.instance.client;
  Future<String?> registerUser({
    required String email,
    required String password,
    required String firstname,
    required String lastname,
    required String role,
    required String qualification,
  }) async{
     try
     {
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      final user = authResponse.user;
      if(user == null)
      {
        return  "User creation Failed";
      }
       await supabase.from('profiles').insert({
        'id': user.id,
        'first_name':firstname,
        'last_name': lastname,
        'role':role,
        'qualification':qualification,
      });
    
      return null;
     }catch(e)
     {
      return e.toString();
     }
  }
  Future<String?> loginUser({
    required String email,
    required String password,
  })async {
    try{
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if(response.user == null)
      {
        return "invalid credentials.";
      }
      return null;
    }catch (e){
      return e.toString();
    }
  }

  Future<String?> getUserRole()async
  {
    try{final user = supabase.auth.currentUser;
    if(user == null) return null;
    final result = await supabase.from('profiles').select('role').eq('id', user.id).single();
     return result['role'];
     }catch(e){
      return null;
     }
  }
}