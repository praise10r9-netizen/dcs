import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'routes.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
    
   await Supabase.initialize(
    url: "https://mvynikefyyjcgkoqzdat.supabase.co",
    anonKey:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12eW5pa2VmeXlqY2drb3F6ZGF0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQxNzA1MDcsImV4cCI6MjA3OTc0NjUwN30.sz1xRjVqSlDJxaFAYltoh1pOggjMgNUR575mOJL-ElI",
    debug:false,
  );
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/register',
      routes: appRoutes,
    );
    }
}